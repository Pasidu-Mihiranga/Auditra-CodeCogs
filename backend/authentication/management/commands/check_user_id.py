from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import PaymentSlip, UserRole


class Command(BaseCommand):
    help = 'Check specific user ID in the database'

    def add_arguments(self, parser):
        parser.add_argument('user_id', type=int, help='User ID to check')

    def handle(self, *args, **options):
        user_id = options['user_id']
        
        try:
            user = User.objects.get(id=user_id)
            
            self.stdout.write(self.style.SUCCESS(f'\nUser ID {user_id} Found:'))
            self.stdout.write('='*60)
            self.stdout.write(f'Username: {user.username}')
            self.stdout.write(f'Email: {user.email}')
            self.stdout.write(f'First Name: {user.first_name}')
            self.stdout.write(f'Last Name: {user.last_name}')
            self.stdout.write(f'Date Joined: {user.date_joined}')
            self.stdout.write(f'Is Active: {user.is_active}')
            self.stdout.write(f'Is Staff: {user.is_staff}')
            self.stdout.write(f'Is Superuser: {user.is_superuser}')
            
            # Check role
            try:
                if hasattr(user, 'role') and user.role:
                    self.stdout.write(f'Role: {user.role.get_role_display()} ({user.role.role})')
                else:
                    self.stdout.write('Role: No role assigned')
            except:
                self.stdout.write('Role: Error retrieving role')
            
            # Check payment slips
            payment_slips = PaymentSlip.objects.filter(user=user)
            self.stdout.write(f'\nPayment Slips: {payment_slips.count()}')
            if payment_slips.exists():
                for slip in payment_slips:
                    self.stdout.write(f'  - Slip #{slip.id}: Month {slip.month}/{slip.year}, Employee #: {slip.employee_number or "Not set"}')
            else:
                self.stdout.write('  No payment slips found')
            
            self.stdout.write('='*60 + '\n')
            
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'\nUser ID {user_id} does NOT exist in the database.'))
            self.stdout.write('\nExisting User IDs:')
            existing_ids = User.objects.values_list('id', flat=True).order_by('id')
            for uid in existing_ids:
                self.stdout.write(f'  - User ID {uid}')
            self.stdout.write('')

