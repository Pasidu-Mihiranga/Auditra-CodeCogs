import json
from django.utils.deprecation import MiddlewareMixin
from .utils import log_action, get_client_ip


class SystemLogMiddleware(MiddlewareMixin):
    def process_response(self, request, response):
        if request.path == '/api/auth/login/' and request.method == 'POST':
            ip = get_client_ip(request)
            try:
                body = json.loads(response.content)
            except (json.JSONDecodeError, Exception):
                return response

            if response.status_code == 200 and 'access' in body:
                user_data = body.get('user', {})
                username = user_data.get('username', 'unknown')
                from django.contrib.auth.models import User
                try:
                    user = User.objects.get(username=username)
                except User.DoesNotExist:
                    user = None

                log_action(
                    action='USER_LOGIN',
                    user=user,
                    description=f"User '{username}' logged in successfully",
                    category='auth',
                    ip_address=ip,
                )

        return response
