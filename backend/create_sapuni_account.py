#!/usr/bin/env python
"""
Create sapuni user account with coordinator role
Run: python manage.py shell < create_sapuni_account.py
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auditra_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.models import UserRole
from django.contrib.auth import authenticate

username = 'sapuni'
password = 'coordinator123'
email = 'sapuni@auditra.com'

print("="*60)
print("Creating sapuni user account...")
print("="*60)

# Check if user already exists
if User.objects.filter(username=username).exists():
    print(f"\n⚠️  User '{username}' already exists!")
    user = User.objects.get(username=username)
    print(f"   Updating password and role...")
    user.set_password(password)
    user.email = email
    user.save()
    print(f"   ✅ Password updated")
else:
    # Create new user
    user = User.objects.create_user(
        username=username,
        email=email,
        password=password,
        first_name='Sapuni',
        last_name=''
    )
    print(f"\n✅ User created: {user.username}")
    print(f"   Email: {user.email}")

# Assign coordinator role
role, role_created = UserRole.objects.get_or_create(
    user=user,
    defaults={'role': 'coordinator'}
)

if not role_created:
    role.role = 'coordinator'
    role.save()
    print(f"   ✅ Role updated to: coordinator")
else:
    print(f"   ✅ Role assigned: coordinator")

# Test authentication
print(f"\n🔐 Testing authentication...")
authenticated_user = authenticate(username=username, password=password)
if authenticated_user:
    print(f"   ✅ Authentication successful!")
    print(f"   ✅ Login will work with:")
    print(f"      Username: {username}")
    print(f"      Password: {password}")
else:
    print(f"   ❌ Authentication failed - there may be an issue")

print("\n" + "="*60)
print("Account setup complete!")
print("="*60)

