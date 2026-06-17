"""Catalog and depreciation API tests."""
import uuid
from unittest.mock import patch
from rest_framework import status

from auditra_backend.test_helpers import BaseAuthAPITestCase, api_client_with_jwt, user_with_role


class TestCatalogAPI(BaseAuthAPITestCase):
    def test_item_catalog_requires_auth_401(self):
        """ItemCatalogListView: anonymous (negative)."""
        res = self.client.get('/api/catalog/items/')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_item_catalog_200(self):
        """ItemCatalogListView: authenticated list."""
        u = user_with_role(f'c_{uuid.uuid4().hex[:8]}', 'field_officer')
        c = api_client_with_jwt(u)
        res = c.get('/api/catalog/items/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_depreciation_policies_200(self):
        """DepreciationPolicyListView.get."""
        u = user_with_role(f'c2_{uuid.uuid4().hex[:8]}', 'field_officer')
        c = api_client_with_jwt(u)
        res = c.get('/api/catalog/depreciation/policies/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_online_search_unauthorized(self):
        """online_search requires authenticated user."""
        res = self.client.post('/api/catalog/online-search/', {'query': 'test', 'category': 'vehicle'})
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_online_search_missing_fields(self):
        """online_search returns 400 if query or category missing."""
        u = user_with_role(f'c_{uuid.uuid4().hex[:8]}', 'field_officer')
        c = api_client_with_jwt(u)
        res = c.post('/api/catalog/online-search/', {'query': ''})
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        res = c.post('/api/catalog/online-search/', {'category': 'vehicle'})
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('catalog.views.scrape_ddg_results')
    def test_online_search_sri_lanka_filter(self, mock_scrape):
        """online_search filters results by Sri Lankan indicators."""
        # One matching result (with 'LKR' in title/snippet), one non-matching (international)
        mock_scrape.return_value = [
            {
                'title': 'Toyota Prius 2018 for Sale in Colombo',
                'snippet': 'Excellent condition Toyota Prius, Price LKR 9,200,000. Located in Malabe.',
                'source': 'ikman.lk'
            },
            {
                'title': 'Toyota Prius 2018 in USA',
                'snippet': 'Buy Prius in California for $15,000.',
                'source': 'craigslist.org'
            }
        ]
        u = user_with_role(f'c_{uuid.uuid4().hex[:8]}', 'field_officer')
        c = api_client_with_jwt(u)
        res = c.post('/api/catalog/online-search/', {'query': 'Toyota Prius 2018', 'category': 'vehicle'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        
        # Verify query appended with Sri Lanka
        mock_scrape.assert_called_once_with('Toyota Prius 2018 Sri Lanka')
        
        # Verify only the Sri Lankan one was parsed and returned
        data = res.json()
        self.assertEqual(len(data), 1)
        self.assertIn('Colombo', data[0]['title'])

    @patch('catalog.views.scrape_ddg_results')
    def test_online_search_fallback(self, mock_scrape):
        """online_search generates fallback if DDG returns nothing."""
        mock_scrape.return_value = []
        u = user_with_role(f'c_{uuid.uuid4().hex[:8]}', 'field_officer')
        c = api_client_with_jwt(u)
        res = c.post('/api/catalog/online-search/', {'query': 'Toyota Prius 2018', 'category': 'vehicle'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertTrue(len(data) > 0)
        self.assertIn('Premium Toyota Prius 2018 - Option A', data[0]['title'])

