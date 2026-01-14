from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole, PaymentSlip


class Command(BaseCommand):
    help = 'Shows user IDs from the database and their corresponding employee numbers in payment slips'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('\n' + '='*80))
        self.stdout.write(self.style.SUCCESS('USER IDs FROM DATABASE'))
        self.stdout.write(self.style.SUCCESS('='*80 + '\n'))
        
        # Get all users
        users = User.objects.all().order_by('id')
        
        if users.count() == 0:
            self.stdout.write(self.style.WARNING('No users found in database!'))
            return
        
        self.stdout.write(f'{"ID":<6} {"Username":<20} {"Email":<30} {"Role":<20} {"Employee # in Payment Slips":<30}')
        self.stdout.write('-'*80)
        
        for user in users:
            # Get user role
            try:
                role = user.role.get_role_display() if hasattr(user, 'role') and user.role else 'N/A'
            except:
                role = 'N/A'
            
            # Get employee numbers from payment slips for this user
            payment_slips = PaymentSlip.objects.filter(user=user)
            employee_numbers = []
            for slip in payment_slips:
                if slip.employee_number:
                    if slip.employee_number not in employee_numbers:
                        employee_numbers.append(slip.employee_number)
            
            employee_numbers_str = ', '.join(employee_numbers) if employee_numbers else 'None'
            if len(employee_numbers_str) > 28:
                employee_numbers_str = employee_numbers_str[:25] + '...'
            
            self.stdout.write(
                f'{user.id:<6} {user.username:<20} {user.email[:28]:<30} {role:<20} {employee_numbers_str:<30}'
            )
        
        self.stdout.write('\n' + '='*80)
        self.stdout.write(self.style.SUCCESS(f'Total Users: {users.count()}'))
        self.stdout.write('='*80 + '\n')
        
        # Show summary of employee number formats
        self.stdout.write(self.style.SUCCESS('\nEMPLOYEE NUMBER FORMAT SUMMARY'))
        self.stdout.write('='*80)
        
        all_employee_numbers = PaymentSlip.objects.exclude(employee_number__isnull=True).exclude(employee_number='').values_list('employee_number', flat=True).distinct()
        
        formats_found = {}
        for emp_num in all_employee_numbers:
            if emp_num.startswith('EMP-'):
                format_type = 'EMP-XXX'
            elif emp_num.startswith('EMP '):
                format_type = 'EMP XXX'
            elif emp_num.startswith('EMP'):
                format_type = 'EMPXXX'
            elif emp_num.isdigit():
                format_type = 'Number only (correct)'
            else:
                format_type = 'Other format'
            
            formats_found[format_type] = formats_found.get(format_type, 0) + 1
        
        for format_type, count in formats_found.items():
            self.stdout.write(f'{format_type}: {count} payment slip(s)')
        
        self.stdout.write('='*80 + '\n')

