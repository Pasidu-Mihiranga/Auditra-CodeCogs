from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from .models import SystemLog
from .serializers import SystemLogSerializer
from .utils import verify_chain, log_action, get_client_ip


class SystemLogListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({'error': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

        qs = SystemLog.objects.select_related('user', 'target_user').order_by('-block_index')

        category = request.query_params.get('category')
        if category:
            qs = qs.filter(category=category)

        action = request.query_params.get('action')
        if action:
            qs = qs.filter(action=action)

        search = request.query_params.get('search')
        if search:
            from django.db.models import Q
            qs = qs.filter(
                Q(description__icontains=search) |
                Q(user__username__icontains=search) |
                Q(user__first_name__icontains=search) |
                Q(user__last_name__icontains=search)
            )

        page = int(request.query_params.get('page', 1))
        page_size = int(request.query_params.get('page_size', 25))
        start = (page - 1) * page_size
        end = start + page_size

        total = qs.count()
        logs = qs[start:end]
        serializer = SystemLogSerializer(logs, many=True)

        return Response({
            'results': serializer.data,
            'count': total,
            'page': page,
            'page_size': page_size,
            'total_pages': (total + page_size - 1) // page_size,
        })


class VerifyChainView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'role') or request.user.role.role != 'admin':
            return Response({'error': 'Only admins can verify the log chain'}, status=status.HTTP_403_FORBIDDEN)

        result = verify_chain()

        log_action(
            action='CHAIN_VERIFIED',
            user=request.user,
            description=f"Chain verification: {result['message']}",
            category='system',
            ip_address=get_client_ip(request),
            metadata=result,
        )

        return Response(result, status=status.HTTP_200_OK)
