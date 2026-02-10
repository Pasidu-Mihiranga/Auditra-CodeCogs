from django.core.management.base import BaseCommand
from authentication.models import PaymentSlip


class Command(BaseCommand):
    help = 'Delete payment slips for employee roles (Coordinator, Field Officer, Senior Valuer, Assessor, MD/GM, HR Head, General Employee)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--confirm',
            action='store_true',
            help='Confirm deletion (required to actually delete)',
        )

    def handle(self, *args, **options):
        # Employee roles to delete payment slips for
        employee_roles = [
            'coordinator',
            'field_officer',
            'senior_valuer',
            'accessor',
            'assessor',  # In case it's stored as 'assessor' instead of 'accessor'
            'md_gm',
            'hr_head',
            'general_employee',
        ]
        
        # Find all payment slips for these roles
        slips_to_delete = PaymentSlip.objects.filter(role__in=employee_roles)
        count = slips_to_delete.count()
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS('No payment slips found for employee roles.'))
            return
        
        self.stdout.write(f'Found {count} payment slip(s) for employee roles:')
        self.stdout.write('')
        
        # Group by role and show count
        for role in employee_roles:
            role_slips = slips_to_delete.filter(role=role)
            if role_slips.exists():
                self.stdout.write(f'  {role}: {role_slips.count()} payment slip(s)')
                # Show sample
                for slip in role_slips[:3]:
                    self.stdout.write(f'    - User: {slip.user.username}, Month: {slip.month}/{slip.year}')
                if role_slips.count() > 3:
                    self.stdout.write(f'    ... and {role_slips.count() - 3} more')
        
        self.stdout.write('')
        
        if not options['confirm']:
            self.stdout.write(self.style.WARNING(
                'This will delete all payment slips for employee roles.'
            ))
            self.stdout.write(self.style.WARNING(
                'Run with --confirm flag to actually delete them.'
            ))
            self.stdout.write('')
            self.stdout.write('Command: python manage.py delete_employee_payment_slips --confirm')
            return
        
        # Delete them
        deleted_count = slips_to_delete.count()
        slips_to_delete.delete()
        
        self.stdout.write(self.style.SUCCESS(
            f'[OK] Deleted {deleted_count} payment slip(s) for employee roles.'
        ))

