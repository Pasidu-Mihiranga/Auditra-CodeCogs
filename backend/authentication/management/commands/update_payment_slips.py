from django.core.management.base import BaseCommand
from authentication.models import PaymentSlip, UserRole
from decimal import Decimal


class Command(BaseCommand):
    help = 'Update existing payment slips with new calculation logic (Allowances=1200, EPF=8%, Net=Basic-EPF+Allowances)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--month',
            type=int,
            help='Update payment slips for a specific month (1-12)',
        )
        parser.add_argument(
            '--year',
            type=int,
            help='Update payment slips for a specific year',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            help='Update all payment slips',
        )

    def handle(self, *args, **options):
        # Get payment slips to update
        if options['all']:
            payment_slips = PaymentSlip.objects.all()
            self.stdout.write(self.style.SUCCESS(f'Updating all payment slips...'))
        elif options['month'] and options['year']:
            payment_slips = PaymentSlip.objects.filter(month=options['month'], year=options['year'])
            self.stdout.write(self.style.SUCCESS(f'Updating payment slips for {options["month"]}/{options["year"]}...'))
        else:
            self.stdout.write(self.style.ERROR('Please specify --all or --month and --year'))
            return

        updated_count = 0
        for slip in payment_slips:
            try:
                # Get current salary from user's role (not from stored slip)
                if hasattr(slip.user, 'role') and slip.user.role:
                    basic_salary = Decimal(str(slip.user.role.salary))
                else:
                    # Fallback to stored salary if role doesn't exist
                    basic_salary = Decimal(str(slip.salary))
                
                # Recalculate with new formulas
                allowances = PaymentSlip.calculate_allowances(basic_salary)
                epf_contribution = PaymentSlip.calculate_epf(basic_salary)
                
                # Get overtime hours (already stored, but recalculate overtime pay)
                overtime_hours = Decimal(str(slip.overtime_hours)) if slip.overtime_hours else Decimal('0')
                overtime_pay = PaymentSlip.calculate_overtime_pay(float(overtime_hours), float(basic_salary))
                
                # New net salary formula: Basic - EPF + Allowances
                net_salary = basic_salary - epf_contribution + allowances
                
                # Update the payment slip with new salary and recalculated values
                slip.salary = basic_salary
                slip.allowances = allowances
                slip.epf_contribution = epf_contribution
                slip.overtime_pay = overtime_pay
                slip.net_salary = net_salary
                # Update role and role_display from current role
                if hasattr(slip.user, 'role') and slip.user.role:
                    slip.role = slip.user.role.role
                    slip.role_display = slip.user.role.role_display
                slip.save()
                
                updated_count += 1
                self.stdout.write(
                    f'Updated payment slip for {slip.user.username} - {slip.get_month_display()} {slip.year}'
                )
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Error updating payment slip {slip.id}: {str(e)}')
                )

        self.stdout.write(
            self.style.SUCCESS(f'\nSuccessfully updated {updated_count} payment slip(s)')
        )

