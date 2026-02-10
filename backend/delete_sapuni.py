import os
import django
import sys

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auditra_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.models import UserRole
from django.db import connection

username = 'sapuni'

print("="*60)
print("DELETING sapuni account I created")
print("="*60)

user = User.objects.filter(username=username).first()

if user:
    print(f"\nFound user: {user.username}")
    print(f"   Email: {user.email}")
    print(f"   Date Joined: {user.date_joined}")
    print(f"   ID: {user.id}")
    
    user_id = user.id
    
    # Delete all related records first
    with connection.cursor() as cursor:
        # Delete attendance records
        try:
            cursor.execute("DELETE FROM attendances WHERE user_id = %s", [user_id])
            print(f"   Deleted attendance records")
        except Exception as e:
            print(f"   Attendance deletion: {e}")
        
        # Delete payment slips
        try:
            cursor.execute("DELETE FROM payment_slips WHERE user_id = %s", [user_id])
            print(f"   Deleted payment slips")
        except Exception as e:
            print(f"   Payment slips deletion: {e}")
        
        # Delete UserRole
        try:
            cursor.execute("DELETE FROM user_roles WHERE user_id = %s", [user_id])
            print(f"   Deleted UserRole")
        except Exception as e:
            print(f"   UserRole deletion: {e}")
    
    # Now delete the user
    try:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM auth_user WHERE id = %s", [user_id])
        print(f"\n[OK] User '{username}' (ID: {user_id}) deleted successfully")
    except Exception as e:
        print(f"\n[ERROR] Could not delete user: {e}")
    
    # Verify deletion
    remaining = User.objects.filter(username=username).first()
    if remaining:
        print("[ERROR] User still exists!")
    else:
        print("[OK] User confirmed deleted")
else:
    print(f"\n[INFO] User '{username}' not found - nothing to delete")

print("\nAll remaining users in database:")
all_users = User.objects.all()
print(f"Total: {all_users.count()}")
for u in all_users:
    print(f"  - {u.username} ({u.email})")

print("\n" + "="*60)
print("Done!")
print("="*60)

