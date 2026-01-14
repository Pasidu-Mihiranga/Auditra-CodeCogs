from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates coordinator user with specified credentials'

    def handle(self, *args, **options):
        # Coordinator credentials
        username = 'sapuni'
        password = 'coordinator123'
        email = 'sapuni@auditra.com'
        
        # Check if coordinator already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(
                f'Coordinator user "{username}" already exists!'
            ))
            coordinator_user = User.objects.get(username=username)
            # Reset password to ensure it's correct
            coordinator_user.set_password(password)
            coordinator_user.save()
            self.stdout.write(self.style.SUCCESS(
                f'Password reset for user: {username}'
            ))
        else:
            # Create coordinator user
            coordinator_user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='Sapuni',
                last_name='Coordinator',
            )
            self.stdout.write(self.style.SUCCESS(
                f'Successfully created coordinator user: {username}'
            ))
        
        # Assign coordinator role
        user_role, created = UserRole.objects.get_or_create(user=coordinator_user)
        user_role.role = 'coordinator'
        user_role.save()
        
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'COORDINATOR CREDENTIALS:'
        ))
        self.stdout.write(self.style.SUCCESS(
            '='*50
        ))
        self.stdout.write(self.style.WARNING(
            f'Username: {username}'
        ))
        self.stdout.write(self.style.WARNING(
            f'Password: {password}'
        ))
        self.stdout.write(self.style.SUCCESS(
            '='*50 + '\n'
        ))
        
        self.stdout.write(self.style.SUCCESS(
            f'Coordinator role assigned successfully!'
        ))

