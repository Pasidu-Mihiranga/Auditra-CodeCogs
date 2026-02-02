import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auditra_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.models import UserRole

print("\n" + "="*50)
print("USER ROLES STATUS")
print("="*50)

for user in User.objects.all():
    if hasattr(user, 'role'):
        print(f"✓ {user.username}: {user.role.role} ({user.role.get_role_display()})")
    else:
        print(f"✗ {user.username}: NO ROLE RECORD")

print("="*50 + "\n")

