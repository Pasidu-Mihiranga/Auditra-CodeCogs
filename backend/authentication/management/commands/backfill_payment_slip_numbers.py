from django.core.management.base import BaseCommand
from django.db.models import Q
from authentication.models import PaymentSlip


class Command(BaseCommand):
    help = 'Backfills employee numbers and payment slip numbers for existing payment slips that are missing them'

    def handle(self, *args, **options):
        updated_count = 0
        skipped_count = 0
        
        # Get all payment slips that are missing employee_number or pay_slip_number
        payment_slips = PaymentSlip.objects.filter(
            Q(employee_number__isnull=True) | 
            Q(employee_number='') |
            Q(pay_slip_number__isnull=True) | 
            Q(pay_slip_number='')
        )
        
        total = payment_slips.count()
        
        if total == 0:
            self.stdout.write(self.style.SUCCESS(
                '✓ All payment slips already have employee numbers and payment slip numbers!'
            ))
            return
        
        self.stdout.write(f'Found {total} payment slip(s) that need updating...\n')
        
        for slip in payment_slips:
            updated = False
            
            # Set employee number to user ID if missing or has wrong format
            if not slip.employee_number:
                slip.employee_number = str(slip.user.id)
                updated = True
                self.stdout.write(f'  ✓ Added employee number {slip.employee_number} for user {slip.user.username} (slip #{slip.id})')
            elif slip.employee_number != str(slip.user.id):
                # Fix format if it has EMP- prefix or other format
                original = slip.employee_number
                if slip.employee_number.startswith('EMP-'):
                    slip.employee_number = slip.employee_number.replace('EMP-', '').strip()
                elif slip.employee_number.startswith('EMP '):
                    slip.employee_number = slip.employee_number.replace('EMP ', '').strip()
                elif slip.employee_number.startswith('EMP'):
                    if len(slip.employee_number) > 3 and slip.employee_number[3:].strip().isdigit():
                        slip.employee_number = slip.employee_number[3:].strip()
                
                # Ensure it's just the user ID
                if not slip.employee_number.isdigit() or slip.employee_number != str(slip.user.id):
                    slip.employee_number = str(slip.user.id)
                
                if original != slip.employee_number:
                    updated = True
                    self.stdout.write(f'  ✓ Fixed employee number for {slip.user.username}: "{original}" → "{slip.employee_number}"')
            
            # Generate payment slip number if missing
            if not slip.pay_slip_number:
                # Check if a payment slip number with this format already exists
                base_number = f"PS-{slip.year}{slip.month:02d}-{slip.user.id}"
                counter = 1
                pay_slip_number = base_number
                
                # If the base number exists, add a counter
                while PaymentSlip.objects.filter(pay_slip_number=pay_slip_number).exclude(id=slip.id).exists():
                    pay_slip_number = f"{base_number}-{counter}"
                    counter += 1
                
                slip.pay_slip_number = pay_slip_number
                updated = True
                self.stdout.write(f'  ✓ Added payment slip number for user {slip.user.username} (slip #{slip.id})')
            
            if updated:
                slip.save()
                updated_count += 1
            else:
                skipped_count += 1
        
        self.stdout.write(self.style.SUCCESS(
            f'\n✓ Backfill complete! Updated {updated_count} payment slip(s), skipped {skipped_count}'
        ))

