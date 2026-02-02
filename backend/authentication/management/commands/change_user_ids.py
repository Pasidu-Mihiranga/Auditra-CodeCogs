from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db import transaction
from authentication.models import PaymentSlip, UserRole
try:
    from attendance.models import Attendance
except ImportError:
    Attendance = None
try:
    from projects.models import Project
except ImportError:
    Project = None
try:
    from valuations.models import Valuation
except ImportError:
    Valuation = None


class Command(BaseCommand):
    help = 'Change user IDs in the database (WARNING: This is a complex operation)'

    def add_arguments(self, parser):
        parser.add_argument('username', type=str, help='Username to change ID for')
        parser.add_argument('new_id', type=int, help='New user ID')

    def handle(self, *args, **options):
        username = options['username']
        new_id = options['new_id']
        
        try:
            user = User.objects.get(username=username)
            old_id = user.id
            
            if old_id == new_id:
                self.stdout.write(self.style.WARNING(f'User {username} already has ID {new_id}'))
                return
            
            # Check if new ID is already taken
            if User.objects.filter(id=new_id).exists():
                self.stdout.write(self.style.ERROR(f'User ID {new_id} is already taken by another user!'))
                return
            
            self.stdout.write(self.style.WARNING(f'\nWARNING: This will change User ID from {old_id} to {new_id}'))
            self.stdout.write(self.style.WARNING('This operation affects multiple database tables.'))
            self.stdout.write(f'\nUser: {username} (ID: {old_id} -> {new_id})')
            
            # Find all related records
            payment_slips = PaymentSlip.objects.filter(user=user)
            user_role = UserRole.objects.filter(user=user).first()
            attendance_count = Attendance.objects.filter(user=user).count() if Attendance else 0
            projects_count = Project.objects.filter(created_by=user).count() if Project and hasattr(Project, 'created_by') else 0
            valuations_count = Valuation.objects.filter(user=user).count() if Valuation and hasattr(Valuation, 'user') else 0
            
            self.stdout.write(f'\nRelated records found:')
            self.stdout.write(f'  - Payment Slips: {payment_slips.count()}')
            self.stdout.write(f'  - User Role: {"Yes" if user_role else "No"}')
            self.stdout.write(f'  - Attendance Records: {attendance_count}')
            self.stdout.write(f'  - Projects: {projects_count}')
            self.stdout.write(f'  - Valuations: {valuations_count}')
            
            confirm = input('\nDo you want to proceed? (yes/no): ')
            if confirm.lower() != 'yes':
                self.stdout.write(self.style.WARNING('Operation cancelled.'))
                return
            
            with transaction.atomic():
                # Update all foreign key references first
                self.stdout.write('\nUpdating related records...')
                
                # Update payment slips
                for slip in payment_slips:
                    slip.user_id = new_id
                    slip.employee_number = str(new_id)  # Update employee number to match new ID
                    slip.save()
                self.stdout.write(f'  [OK] Updated {payment_slips.count()} payment slip(s)')
                
                # Update user role
                if user_role:
                    user_role.user_id = new_id
                    user_role.save()
                    self.stdout.write('  [OK] Updated user role')
                
                # Update attendance records
                if Attendance:
                    Attendance.objects.filter(user_id=old_id).update(user_id=new_id)
                    self.stdout.write(f'  [OK] Updated attendance records')
                
                # Update projects
                if Project and hasattr(Project, 'created_by'):
                    Project.objects.filter(created_by_id=old_id).update(created_by_id=new_id)
                    self.stdout.write(f'  [OK] Updated projects')
                
                # Update valuations
                if Valuation and hasattr(Valuation, 'user'):
                    Valuation.objects.filter(user_id=old_id).update(user_id=new_id)
                    self.stdout.write(f'  [OK] Updated valuations')
                
                # Update the user ID using raw SQL (Django doesn't support changing primary keys directly)
                from django.db import connection
                with connection.cursor() as cursor:
                    # Update auth_user table
                    cursor.execute("UPDATE auth_user SET id = %s WHERE id = %s", [new_id, old_id])
                    
                    # Update any other tables that might reference the user
                    # Update user_roles
                    cursor.execute("UPDATE user_roles SET user_id = %s WHERE user_id = %s", [new_id, old_id])
                    
                    # Update payment_slips
                    cursor.execute("UPDATE payment_slips SET user_id = %s WHERE user_id = %s", [new_id, old_id])
                    
                    # Update employee_number in payment_slips to match new ID
                    cursor.execute("UPDATE payment_slips SET employee_number = %s WHERE user_id = %s", [str(new_id), new_id])
                
                self.stdout.write(f'  [OK] Updated user ID from {old_id} to {new_id}')
                
            self.stdout.write(self.style.SUCCESS(f'\n[SUCCESS] User {username} ID changed from {old_id} to {new_id}'))
            self.stdout.write(self.style.SUCCESS('All related records have been updated.'))
            
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'User "{username}" not found!'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error: {str(e)}'))
            import traceback
            self.stdout.write(traceback.format_exc())

