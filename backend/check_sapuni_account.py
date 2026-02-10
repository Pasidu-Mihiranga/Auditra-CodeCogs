#!/usr/bin/env python
"""
Check sapuni user account and password
Run: python manage.py shell < check_sapuni_account.py
Or: python manage.py shell, then copy-paste this code
"""

from django.contrib.auth.models import User
from authentication.models import UserRole
from django.contrib.auth import authenticate

username = 'sapuni'
password = 'coordinator123'

print("="*60)
print(f"Checking account for username: {username}")
print("="*60)

# Check if user exists
try:
    user = User.objects.get(username=username)
    print(f"\n✅ User FOUND: {user.username}")
    print(f"   Email: {user.email}")
    print(f"   First Name: {user.first_name}")
    print(f"   Last Name: {user.last_name}")
    print(f"   Date Joined: {user.date_joined}")
    print(f"   Is Active: {user.is_active}")
    print(f"   Is Staff: {user.is_staff}")
    print(f"   Is Superuser: {user.is_superuser}")
    
    # Check if user has a role
    try:
        role = user.role
        print(f"   Role: {role.role} ({role.role_display})")
        print(f"   Role Created: {role.created_at}")
    except UserRole.DoesNotExist:
        print("   ⚠️  WARNING: User has NO role assigned!")
        print("   Creating role now...")
        UserRole.objects.create(user=user, role='unassigned')
        print("   ✅ Role created successfully!")
    
    # Test password authentication
    print(f"\n🔐 Testing password authentication...")
    print(f"   Testing password: {password}")
    
    authenticated_user = authenticate(username=username, password=password)
    if authenticated_user:
        print("   ✅ Password is CORRECT - Authentication successful!")
        print(f"   Authenticated user: {authenticated_user.username}")
    else:
        print("   ❌ Password is INCORRECT - Authentication failed!")
        print("\n   Possible solutions:")
        print("   1. The password might be different")
        print("   2. Reset the password using:")
        print(f"      python manage.py changepassword {username}")
        print("\n   To reset password now, run:")
        print(f"   user.set_password('{password}')")
        print("   user.save()")
    
    # Check for case variations
    print("\n📋 Checking for username case variations...")
    similar_users = User.objects.filter(username__iexact=username)
    if similar_users.count() > 1:
        print(f"   ⚠️  Found {similar_users.count()} users with similar username:")
        for u in similar_users:
            print(f"      - {u.username} (ID: {u.id}, Email: {u.email})")
    
except User.DoesNotExist:
    print(f"\n❌ User '{username}' NOT FOUND in database!")
    
    # Check for similar usernames
    print("\n🔍 Searching for similar usernames...")
    similar = User.objects.filter(username__icontains='sap')[:10]
    if similar.exists():
        print(f"   Found {similar.count()} users with 'sap' in username:")
        for u in similar:
            print(f"      - {u.username} (Email: {u.email})")
    else:
        print("   No similar usernames found.")
    
    print("\n   The account might:")
    print("   1. Have a different username (check case sensitivity)")
    print("   2. Not have been created successfully")
    print("   3. Have been deleted")

print("\n" + "="*60)
print("Diagnostic complete!")
print("="*60)

