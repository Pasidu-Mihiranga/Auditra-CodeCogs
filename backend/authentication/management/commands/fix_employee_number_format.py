from django.core.management.base import BaseCommand
from authentication.models import PaymentSlip


class Command(BaseCommand):
    help = 'Fixes employee number format to use only user ID (removes EMP- prefix if present)'

    def handle(self, *args, **options):
        # Get all payment slips
        payment_slips = PaymentSlip.objects.all()
        
        total = payment_slips.count()
        
        if total == 0:
            self.stdout.write(self.style.SUCCESS(
                '[OK] No payment slips found!'
            ))
            return
        
        self.stdout.write(f'Found {total} payment slip(s) to check...\n')
        
        updated_count = 0
        skipped_count = 0
        
        for slip in payment_slips:
            updated = False
            original_number = slip.employee_number
            
            # Check if employee number has EMP- or EMP prefix
            if slip.employee_number:
                # Remove EMP- or EMP prefix if present
                if slip.employee_number.startswith('EMP-'):
                    slip.employee_number = slip.employee_number.replace('EMP-', '').strip()
                    updated = True
                elif slip.employee_number.startswith('EMP '):
                    slip.employee_number = slip.employee_number.replace('EMP ', '').strip()
                    updated = True
                elif slip.employee_number.startswith('EMP'):
                    # Handle case where there's no space or dash
                    if len(slip.employee_number) > 3 and slip.employee_number[3:].strip().isdigit():
                        slip.employee_number = slip.employee_number[3:].strip()
                        updated = True
                
                # Ensure it's just the user ID
                if updated or not slip.employee_number.isdigit():
                    # If it's not a pure number, set it to user ID
                    slip.employee_number = str(slip.user.id)
                    if not updated:
                        updated = True
            else:
                # If no employee number, set it to user ID
                slip.employee_number = str(slip.user.id)
                updated = True
            
            if updated:
                slip.save(update_fields=['employee_number'])
                updated_count += 1
                if original_number != slip.employee_number:
                    self.stdout.write(self.style.SUCCESS(
                        f'  [OK] Updated {slip.user.username}: "{original_number}" -> "{slip.employee_number}" (User ID: {slip.user.id})'
                    ))
                else:
                    self.stdout.write(self.style.SUCCESS(
                        f'  [OK] Set employee number {slip.employee_number} for {slip.user.username} (User ID: {slip.user.id})'
                    ))
            else:
                skipped_count += 1
                self.stdout.write(self.style.WARNING(
                    f'  [-] Skipped {slip.user.username} (already correct: {slip.employee_number})'
                ))
        
        self.stdout.write(self.style.SUCCESS(
            f'\n[OK] Fix complete! Updated {updated_count} payment slip(s), skipped {skipped_count}'
        ))

