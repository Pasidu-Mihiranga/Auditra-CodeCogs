#!/usr/bin/env python
"""
Setup verification script for Auditra backend
Run this to check if everything is configured correctly
"""

import sys
import os

def check_python_version():
    """Check Python version"""
    version = sys.version_info
    print(f"✓ Python {version.major}.{version.minor}.{version.micro}")
    if version.major < 3 or (version.major == 3 and version.minor < 9):
        print("⚠ Warning: Python 3.9+ recommended")
        return False
    return True

def check_dependencies():
    """Check if required packages are installed"""
    required = [
        'django',
        'rest_framework',
        'psycopg',
        'corsheaders',
        'decouple',
        'rest_framework_simplejwt'
    ]
    
    missing = []
    for package in required:
        try:
            __import__(package)
            print(f"✓ {package} installed")
        except ImportError:
            print(f"✗ {package} NOT installed")
            missing.append(package)
    
    return len(missing) == 0

def check_env_file():
    """Check if .env file exists"""
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        print(f"✓ .env file found")
        return True
    else:
        print(f"✗ .env file NOT found")
        print("  Create .env with database configuration")
        return False

def check_database():
    """Check database connection"""
    try:
        import django
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auditra_backend.settings')
        django.setup()
        
        from django.db import connection
        connection.ensure_connection()
        print("✓ Database connection successful")
        return True
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        print("  Make sure PostgreSQL is running and configured correctly")
        return False

def check_migrations():
    """Check if migrations are applied"""
    try:
        from django.core.management import call_command
        from io import StringIO
        
        out = StringIO()
        call_command('showmigrations', '--plan', stdout=out)
        output = out.getvalue()
        
        if '[X]' in output or output.strip() == '':
            print("✓ Migrations are up to date")
            return True
        else:
            print("⚠ Migrations need to be applied")
            print("  Run: python manage.py migrate")
            return False
    except Exception as e:
        print(f"⚠ Could not check migrations: {e}")
        return False

def main():
    print("=" * 50)
    print("Auditra Backend Setup Verification")
    print("=" * 50)
    print()
    
    checks = [
        ("Python Version", check_python_version),
        ("Dependencies", check_dependencies),
        ("Environment File", check_env_file),
        ("Database Connection", check_database),
        ("Migrations", check_migrations),
    ]
    
    results = []
    for name, check_func in checks:
        print(f"\nChecking {name}...")
        try:
            result = check_func()
            results.append(result)
        except Exception as e:
            print(f"✗ Error: {e}")
            results.append(False)
    
    print("\n" + "=" * 50)
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"✓ All checks passed! ({passed}/{total})")
        print("\nYou're ready to run: python manage.py runserver")
    else:
        print(f"⚠ {passed}/{total} checks passed")
        print("\nPlease fix the issues above before running the server")
    
    print("=" * 50)
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

