from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates UserRole records for all users who dont have one'

    def handle(self, *args, **options):
        users_without_role = []
        users_fixed = 0
        
        for user in User.objects.all():
            # Check if UserRole exists for this user
            try:
                user.role
                # Role exists, skip
            except UserRole.DoesNotExist:
                # Create role for this user
                if user.username == 'admin' and user.is_superuser:
                    # Admin user gets admin role
                    UserRole.objects.create(user=user, role='admin')
                    self.stdout.write(self.style.SUCCESS(
                        f'✓ Created admin role for: {user.username}'
                    ))
                else:
                    # Other users get unassigned role
                    UserRole.objects.create(user=user, role='unassigned')
                    self.stdout.write(self.style.SUCCESS(
                        f'✓ Created unassigned role for: {user.username}'
                    ))
                users_fixed += 1
        
        if users_fixed == 0:
            self.stdout.write(self.style.SUCCESS(
                '✓ All users already have roles assigned!'
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f'\n✓ Fixed {users_fixed} user(s) - All users now have roles!'
            ))

