from django.core.management.base import BaseCommand
from authentication.models import PaymentSlip


class Command(BaseCommand):
    help = 'Verifies that all payment slips use user ID as employee number'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('\n' + '='*80))
        self.stdout.write(self.style.SUCCESS('VERIFYING EMPLOYEE NUMBERS IN PAYMENT SLIPS'))
        self.stdout.write(self.style.SUCCESS('='*80 + '\n'))
        
        all_slips = PaymentSlip.objects.all().order_by('user__id', 'year', 'month')
        
        if all_slips.count() == 0:
            self.stdout.write(self.style.WARNING('No payment slips found!'))
            return
        
        correct_count = 0
        incorrect_count = 0
        
        self.stdout.write(f'{"User ID":<10} {"Username":<20} {"Month/Year":<12} {"Employee #":<15} {"Status":<20}')
        self.stdout.write('-'*80)
        
        for slip in all_slips:
            expected = str(slip.user.id)
            actual = slip.employee_number or 'None'
            
            if actual == expected:
                status = '[OK] Correct'
                correct_count += 1
                style = self.style.SUCCESS
            else:
                status = '[ERROR] Wrong'
                incorrect_count += 1
                style = self.style.ERROR
            
            self.stdout.write(style(
                f'{slip.user.id:<10} {slip.user.username:<20} {slip.month}/{slip.year:<11} {actual:<15} {status:<20}'
            ))
        
        self.stdout.write('\n' + '='*80)
        self.stdout.write(self.style.SUCCESS(f'Total Payment Slips: {all_slips.count()}'))
        self.stdout.write(self.style.SUCCESS(f'Correct: {correct_count}'))
        if incorrect_count > 0:
            self.stdout.write(self.style.ERROR(f'Incorrect: {incorrect_count}'))
        else:
            self.stdout.write(self.style.SUCCESS(f'Incorrect: {incorrect_count}'))
        self.stdout.write('='*80 + '\n')
        
        if incorrect_count == 0:
            self.stdout.write(self.style.SUCCESS('\n[SUCCESS] All payment slips are using user ID as employee number!'))
        else:
            self.stdout.write(self.style.ERROR('\n[WARNING] Some payment slips need to be fixed.'))
            self.stdout.write(self.style.WARNING('Run: python manage.py fix_employee_number_format'))

