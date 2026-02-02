"""
Diagnostic script to check user account status
Run this to verify if a user account exists and can login
Usage: python manage.py shell < check_user_account.py
Or: python manage.py shell
Then copy-paste the code below
"""

from django.contrib.auth.models import User
from authentication.models import UserRole
from django.contrib.auth import authenticate

# Replace with the username you want to check
username_to_check = input("Enter username to check: ").strip()

try:
    user = User.objects.get(username=username_to_check)
    print(f"\n✅ User found: {user.username}")
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
        print("   This might cause login issues.")
        print("   Fix: Creating role now...")
        UserRole.objects.create(user=user, role='unassigned')
        print("   ✅ Role created successfully!")
    
    # Test password
    print("\n🔐 Testing password authentication...")
    test_password = input("Enter password to test (or press Enter to skip): ").strip()
    
    if test_password:
        authenticated_user = authenticate(username=username_to_check, password=test_password)
        if authenticated_user:
            print("   ✅ Password is CORRECT - Authentication successful!")
        else:
            print("   ❌ Password is INCORRECT - Authentication failed!")
            print("\n   Possible issues:")
            print("   1. Password was entered incorrectly")
            print("   2. Password was changed after registration")
            print("   3. Password hashing issue in database")
            print("\n   Solution: Reset the password using Django admin or:")
            print(f"   python manage.py changepassword {username_to_check}")
    else:
        print("   ⏭️  Password test skipped")
    
    # Check all users with similar usernames (case variations)
    print("\n📋 Checking for similar usernames (case variations)...")
    similar_users = User.objects.filter(username__iexact=username_to_check)
    if similar_users.count() > 1:
        print(f"   ⚠️  Found {similar_users.count()} users with similar username:")
        for u in similar_users:
            print(f"      - {u.username} (ID: {u.id})")
        print("   Note: Usernames are case-sensitive in Django!")
    
except User.DoesNotExist:
    print(f"\n❌ User '{username_to_check}' NOT FOUND in database!")
    print("\n   Possible reasons:")
    print("   1. Username was entered incorrectly")
    print("   2. Account was not created successfully")
    print("   3. Account was deleted")
    print("   4. Username has different case (Django usernames are case-sensitive)")
    
    # Suggest similar usernames
    similar = User.objects.filter(username__icontains=username_to_check[:3])[:5]
    if similar.exists():
        print(f"\n   Did you mean one of these?")
        for u in similar:
            print(f"      - {u.username} (Email: {u.email})")

print("\n" + "="*60)
print("Diagnostic complete!")
print("="*60)

