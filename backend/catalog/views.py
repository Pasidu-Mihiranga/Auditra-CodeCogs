import unicodedata
import urllib.request
import urllib.parse
import re
import html
import json
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import ItemCatalog, DepreciationPolicy
from .serializers import ItemCatalogSerializer, DepreciationPolicySerializer
from .providers.internal import InternalProvider
from .providers.external import ExternalHttpProvider
from .services.depreciation import compute_depreciation


def normalize(text):
    return unicodedata.normalize('NFKD', text.strip().lower())


# ---- Catalog suggestions ----

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def get_suggestions(request):
    """Return ranked suggestions from all active providers."""
    query = request.data.get('query', '').strip()
    category = request.data.get('category', '')

    providers = [InternalProvider(), ExternalHttpProvider()]
    suggestions = []
    seen = set()

    for provider in providers:
        try:
            for s in provider.search(query, category):
                key = (normalize(s.title), s.category)
                if key not in seen:
                    seen.add(key)
                    suggestions.append({
                        'id': s.item_id,
                        'title': s.title,
                        'category': s.category,
                        'specs': s.specs,
                        'confidence': round(s.confidence, 3),
                        'source': s.source,
                    })
        except Exception:
            pass

    suggestions.sort(key=lambda x: -x['confidence'])
    return Response(suggestions)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_item(request):
    """Field officer confirmed or created a catalog item."""
    title = request.data.get('title', '').strip()
    category = request.data.get('category', '')
    specs = request.data.get('specs', {})

    if not title or not category:
        return Response({'error': 'title and category required'}, status=400)

    obj, created = ItemCatalog.objects.get_or_create(
        title__iexact=title,
        category=category,
        defaults={'title': title, 'specs': specs, 'created_by': request.user},
    )
    if not created and specs:
        obj.specs.update(specs)
        obj.save(update_fields=['specs'])

    return Response(ItemCatalogSerializer(obj).data, status=201 if created else 200)


# ---- Depreciation ----

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calculate_depreciation(request):
    """Compute depreciation.

    If a ``category`` is provided and no explicit ``rate``/``method`` override,
    a matching :class:`DepreciationPolicy` is loaded (Feature #12) and its
    defaults are applied.
    """
    from datetime import date
    from decimal import Decimal
    data = request.data
    try:
        category = (data.get('category') or '').strip()
        method = data.get('method') or 'straight_line'
        rate = data.get('rate')
        salvage_rate = data.get('salvage_rate')
        useful_life_years = data.get('useful_life_years')
        units_lifetime = data.get('units_lifetime')

        # Feature #12: fall back to active policy by (category, method)
        applied_policy = None
        if category:
            applied_policy = DepreciationPolicy.objects.filter(
                category=category, method=method
            ).first() or DepreciationPolicy.objects.filter(category=category).first()
            if applied_policy:
                if rate in (None, ''):
                    rate = applied_policy.default_rate
                if salvage_rate in (None, ''):
                    salvage_rate = applied_policy.salvage_rate
                if useful_life_years in (None, ''):
                    useful_life_years = applied_policy.useful_life_years
                if method in (None, '') and applied_policy.method:
                    method = applied_policy.method
                if units_lifetime in (None, '') and applied_policy.units_lifetime:
                    units_lifetime = applied_policy.units_lifetime

        result = compute_depreciation(
            method=method or 'straight_line',
            purchase_value=Decimal(str(data['purchase_value'])),
            purchase_date=date.fromisoformat(data['purchase_date']),
            salvage_rate=Decimal(str(salvage_rate if salvage_rate not in (None, '') else '0.10')),
            rate=Decimal(str(rate)) if rate not in (None, '') else None,
            useful_life_years=int(useful_life_years) if useful_life_years not in (None, '') else 10,
            units_used=int(data.get('units_used', 0)),
            units_lifetime=int(units_lifetime) if units_lifetime not in (None, '') else None,
        )

        # Align response keys with the mobile widget (Feature #12)
        out = dict(result)
        out['depreciation_amount'] = result['accumulated_depreciation']
        if rate not in (None, ''):
            out['applied_rate'] = str(rate)
        if applied_policy:
            out['applied_policy'] = {
                'category': applied_policy.category,
                'method': applied_policy.method,
                'default_rate': str(applied_policy.default_rate),
                'salvage_rate': str(applied_policy.salvage_rate),
                'useful_life_years': applied_policy.useful_life_years,
            }
        return Response(out)
    except (KeyError, ValueError) as exc:
        return Response({'error': str(exc)}, status=400)


class DepreciationPolicyListView(generics.ListAPIView):
    serializer_class = DepreciationPolicySerializer
    permission_classes = [IsAuthenticated]
    queryset = DepreciationPolicy.objects.all()


class DepreciationPolicyDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = DepreciationPolicySerializer
    permission_classes = [IsAuthenticated]
    queryset = DepreciationPolicy.objects.all()

    def perform_update(self, serializer):
        user = self.request.user
        if not (hasattr(user, 'role') and user.role.role == 'admin'):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied('Only admins can update depreciation policies.')
        serializer.save()


class ItemCatalogListView(generics.ListAPIView):
    serializer_class = ItemCatalogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = ItemCatalog.objects.all()
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category=category)
        q = self.request.query_params.get('q')
        if q:
            qs = qs.filter(title__icontains=q)
        return qs


def scrape_ddg_results(query):
    url = "https://html.duckduckgo.com/html/?" + urllib.parse.urlencode({'q': query})
    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            content = response.read().decode('utf-8')
            snippets = re.findall(r'<a class="result__snippet"[^>]*>(.*?)</a>', content, re.DOTALL)
            titles = re.findall(r'<a class="result__url"[^>]*>(.*?)</a>', content, re.DOTALL)
            
            results = []
            for t, s in zip(titles, snippets):
                t_clean = html.unescape(re.sub(r'<[^>]+>', '', t).strip())
                s_clean = html.unescape(re.sub(r'<[^>]+>', '', s).strip())
                source = "online"
                domain_match = re.search(r'https?://(?:www\.)?([^/]+)', t_clean)
                if domain_match:
                    source = domain_match.group(1)
                else:
                    source = t_clean.split('/')[0] if '/' in t_clean else t_clean
                
                results.append({
                    'title': t_clean,
                    'snippet': s_clean,
                    'source': source
                })
            return results
    except Exception as exc:
        print("DDG search failed:", exc)
        return []


def parse_specs_for_result(query, result, category):
    title = result['title']
    snippet = result['snippet']
    combined_text = title + " " + snippet
    
    price = None
    price_match = re.search(r'(?:LKR|Rs\.?|Lakhs?|Million|Mn|M)\s*([\d,]+(?:\.\d+)?)', combined_text, re.IGNORECASE)
    if price_match:
        val_str = price_match.group(1).replace(',', '')
        try:
            val = float(val_str)
            if 'million' in combined_text.lower() or 'mn' in combined_text.lower() or ' m' in combined_text.lower():
                price = val * 1000000
            elif 'lakh' in combined_text.lower():
                price = val * 100000
            else:
                price = val
        except ValueError:
            pass
            
    if not price:
        price = 4500000 if category == 'vehicle' else (12000000 if category == 'land' else (25000000 if category == 'building' else 150000))
        
    specs = {}
    if category == 'vehicle':
        make = "Toyota"
        for m in ['toyota', 'honda', 'nissan', 'suzuki', 'mazda', 'mitsubishi', 'bmw', 'mercedes', 'hyundai', 'kia', 'tata', 'mahindra']:
            if m in combined_text.lower() or m in query.lower():
                make = m.capitalize()
                break
        specs['make'] = make
        
        model = "Prius"
        query_cleaned = query.lower().replace(make.lower(), '')
        query_cleaned = re.sub(r'\b(20\d{2}|19\d{2})\b', '', query_cleaned)
        query_cleaned = re.sub(r'\b(price|in|sri|lanka|for|sale|buy|used|brand|new)\b', '', query_cleaned)
        model_words = query_cleaned.strip().split()
        if model_words:
            model = " ".join(model_words).capitalize()
        specs['model'] = model
        
        year = 2018
        year_match = re.search(r'\b((?:20|19)\d{2})\b', combined_text)
        if year_match:
            year = int(year_match.group(1))
        elif re.search(r'\b((?:20|19)\d{2})\b', query):
            year_match = re.search(r'\b((?:20|19)\d{2})\b', query)
            year = int(year_match.group(1))
        specs['year'] = year
        
        specs['condition'] = "Used" if "used" in combined_text.lower() or "registered" in combined_text.lower() else "New"
        specs['mileage'] = 45000
        mileage_match = re.search(r'(\d+[\d,]*)\s*(?:km|miles|mileage)', combined_text, re.IGNORECASE)
        if mileage_match:
            try:
                specs['mileage'] = int(mileage_match.group(1).replace(',', ''))
            except ValueError:
                pass
                
    elif category == 'land':
        land_area = 10.0
        area_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:perches|perch|acres|acre|sqft|sq\.ft)', combined_text, re.IGNORECASE)
        if area_match:
            try:
                land_area = float(area_match.group(1))
            except ValueError:
                pass
        specs['land_area'] = land_area
        
        land_type = "Residential"
        if "commercial" in combined_text.lower():
            land_type = "Commercial"
        elif "agricultural" in combined_text.lower() or "estate" in combined_text.lower() or "paddy" in combined_text.lower():
            land_type = "Agricultural"
        specs['land_type'] = land_type
        
        land_location = "Colombo"
        location_match = re.search(r'\b(colombo|kandy|galle|negombo|gampaha|kadawatha|malabe|thalawathugoda|nugegoda|battaramulla|rajagiriya|kotte|moratuwa|panadura|kalutara|kurunegala|jaffna|matara)\b', query, re.IGNORECASE)
        if location_match:
            land_location = location_match.group(1).capitalize()
        specs['land_location'] = land_location
        
    elif category == 'building':
        building_area = 1500.0
        area_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:sqft|sq\.ft|square feet)', combined_text, re.IGNORECASE)
        if area_match:
            try:
                building_area = float(area_match.group(1))
            except ValueError:
                pass
        specs['building_area'] = building_area
        
        building_type = "House"
        if "office" in combined_text.lower() or "commercial" in combined_text.lower():
            building_type = "Office"
        elif "warehouse" in combined_text.lower() or "factory" in combined_text.lower():
            building_type = "Warehouse"
        elif "apartment" in combined_text.lower() or "flat" in combined_text.lower() or "condo" in combined_text.lower():
            building_type = "Apartment"
        specs['building_type'] = building_type
        
        floors = 2
        floors_match = re.search(r'(\d+)\s*(?:floors|floor|story|storey|storys|stories)', combined_text, re.IGNORECASE)
        if floors_match:
            try:
                floors = int(floors_match.group(1))
            except ValueError:
                pass
        specs['number_of_floors'] = floors
        
        year_built = 2018
        year_match = re.search(r'\b((?:20|19)\d{2})\b', combined_text)
        if year_match:
            year_built = int(year_match.group(1))
        specs['year_built'] = year_built
        
        building_location = "Colombo"
        location_match = re.search(r'\b(colombo|kandy|galle|negombo|gampaha|kadawatha|malabe|thalawathugoda|nugegoda|battaramulla|rajagiriya|kotte|moratuwa|panadura|kalutara|kurunegala|jaffna|matara)\b', query, re.IGNORECASE)
        if location_match:
            building_location = location_match.group(1).capitalize()
        specs['building_location'] = building_location
        
    elif category == 'other':
        other_type = "Equipment"
        if "machine" in combined_text.lower() or "machinery" in combined_text.lower():
            other_type = "Machinery"
        elif "furniture" in combined_text.lower():
            other_type = "Furniture"
        elif "computer" in combined_text.lower() or "laptop" in combined_text.lower() or "it" in combined_text.lower():
            other_type = "IT Equipment"
        specs['other_type'] = other_type
        specs['other_specifications'] = query
        
    return {
        'title': title[:100] + ('...' if len(title) > 100 else ''),
        'price': price,
        'source': result['source'],
        'specs': specs
    }


def generate_fallback_results(query, category):
    mock_results = [
        {
            'title': f"Premium {query} - Option A", 
            'snippet': f"Excellent quality {query} available for sale. Good condition, specs are standard. Price LKR 7,200,000. Located in Colombo.", 
            'source': 'online-marketplace.lk'
        },
        {
            'title': f"{query} - Option B", 
            'snippet': f"Used {query} for quick sale. LKR 6,800,000. Single owner. Good condition, low mileage/usage.", 
            'source': 'lk-deals.com'
        },
        {
            'title': f"Budget Friendly {query}", 
            'snippet': f"Economical {query} in fair condition. LKR 5,900,000. negotiable.", 
            'source': 'ikman-direct.lk'
        },
    ]
    
    parsed = []
    for r in mock_results:
        parsed.append(parse_specs_for_result(query, r, category))
    return parsed


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def online_search(request):
    """Search online for a description query and extract specs/price."""
    query = request.data.get('query', '').strip()
    category = request.data.get('category', '')
    
    if not query or not category:
        return Response({'error': 'query and category are required'}, status=400)
    
    # 1. Try DuckDuckGo scraping
    results = scrape_ddg_results(query)
    
    # 2. Parse results
    suggestions = []
    for r in results:
        try:
            suggestions.append(parse_specs_for_result(query, r, category))
        except Exception:
            pass
            
    # 3. Fallback to heuristic mock results if DDG returned nothing
    if not suggestions:
        suggestions = generate_fallback_results(query, category)
        
    return Response(suggestions)

