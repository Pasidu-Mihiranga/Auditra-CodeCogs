#!/usr/bin/env python
"""
Verify if sapuni account exists in database
Run: python manage.py shell < verify_sapuni_account.py
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

print("="*60)
print("Checking if sapuni account exists in database...")
print("="*60)

# Check exact username match
user_exact = User.objects.filter(username=username).first()
user_case = User.objects.filter(username__iexact=username).first()

if user_exact:
    user = user_exact
    print(f"\n✅ User FOUND (exact match): {user.username}")
elif user_case:
    user = user_case
    print(f"\n✅ User FOUND (case variation): {user.username}")
    print(f"   Note: Username case is different: '{user.username}' vs '{username}'")
else:
    print(f"\n❌ User '{username}' NOT FOUND in database")
    print("\n=== All users in database ===")
    all_users = User.objects.all().order_by('username')
    print(f"Total users: {all_users.count()}")
    for u in all_users:
        try:
            role = u.role.role
        except:
            role = "NO ROLE"
        print(f"  {u.id}: {u.username} ({u.email}) - Role: {role}")
    
    print("\n=== Searching for similar usernames ===")
    similar = User.objects.filter(username__icontains='sap')[:10]
    if similar.exists():
        print(f"Found {similar.count()} users with 'sap' in username:")
        for u in similar:
            print(f"  - {u.username} (Email: {u.email})")
    else:
        print("No users found with 'sap' in username")
    
    exit()

# If user found, show details
print(f"\n📋 User Details:")
print(f"   Username: {user.username}")
print(f"   Email: {user.email}")
print(f"   First Name: {user.first_name}")
print(f"   Last Name: {user.last_name}")
print(f"   Date Joined: {user.date_joined}")
print(f"   Is Active: {user.is_active}")
print(f"   Is Staff: {user.is_staff}")
print(f"   Is Superuser: {user.is_superuser}")

# Check role
try:
    role = user.role
    print(f"\n👤 Role Information:")
    print(f"   Role: {role.role}")
    print(f"   Role Display: {role.role_display}")
    print(f"   Role Created: {role.created_at}")
    print(f"   Assigned By: {role.assigned_by.username if role.assigned_by else 'System'}")
except UserRole.DoesNotExist:
    print(f"\n⚠️  WARNING: User has NO role assigned!")

# Test password
print(f"\n🔐 Testing Password Authentication:")
print(f"   Username: {user.username}")
print(f"   Password: {password}")

authenticated_user = authenticate(username=user.username, password=password)
if authenticated_user:
    print(f"   ✅ Password is CORRECT - Authentication successful!")
    print(f"\n✅ Account is valid and ready for login!")
else:
    print(f"   ❌ Password is INCORRECT - Authentication failed!")
    print(f"\n⚠️  The password '{password}' does not match the stored password.")
    print(f"\n   Possible reasons:")
    print(f"   1. Password was changed after account creation")
    print(f"   2. Different password was used during registration")
    print(f"   3. Password has special characters that need escaping")
    print(f"\n   To reset password, run:")
    print(f"   python manage.py changepassword {user.username}")

print("\n" + "="*60)
print("Verification complete!")
print("="*60)

