from django.core.management.base import BaseCommand
from authentication.models import PaymentSlip
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Delete payment slips that were not created by admin (generated_by is None)'

    def handle(self, *args, **options):
        # Find all payment slips without generated_by
        slips_to_delete = PaymentSlip.objects.filter(generated_by__isnull=True)
        count = slips_to_delete.count()
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS('No payment slips to clean up. All payment slips have generated_by set.'))
            return
        
        self.stdout.write(f'Found {count} payment slip(s) without generated_by:')
        for slip in slips_to_delete:
            self.stdout.write(f'  - User: {slip.user.username}, Month: {slip.month}/{slip.year}')
        
        # Delete them
        slips_to_delete.delete()
        
        self.stdout.write(self.style.SUCCESS(f'\n[OK] Deleted {count} payment slip(s) that were not created by admin.'))

