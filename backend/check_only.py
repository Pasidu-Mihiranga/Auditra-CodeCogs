import os
import django
import sys

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auditra_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.models import UserRole
from django.contrib.auth import authenticate

username = 'sapuni'
password = 'coordinator123'

print("="*60)
print("CHECKING DATABASE - NO CREATION")
print("="*60)

# Check if user exists
user = User.objects.filter(username=username).first()
if not user:
    user = User.objects.filter(username__iexact=username).first()

if user:
    print(f"\n[OK] USER EXISTS: {user.username}")
    print(f"   Email: {user.email}")
    print(f"   Is Active: {user.is_active}")
    print(f"   Date Joined: {user.date_joined}")
    
    try:
        print(f"   Role: {user.role.role}")
    except:
        print(f"   Role: NO ROLE")
    
    # Test password
    auth = authenticate(username=user.username, password=password)
    if auth:
        print(f"\n[OK] PASSWORD IS CORRECT")
        print(f"   Login should work with:")
        print(f"   Username: {user.username}")
        print(f"   Password: {password}")
    else:
        print(f"\n[ERROR] PASSWORD IS INCORRECT")
        print(f"   The password '{password}' does not match")
else:
    print(f"\n[ERROR] USER '{username}' NOT FOUND")
    print(f"\nAll users in database:")
    for u in User.objects.all():
        print(f"  - {u.username} ({u.email})")

print("\n" + "="*60)

