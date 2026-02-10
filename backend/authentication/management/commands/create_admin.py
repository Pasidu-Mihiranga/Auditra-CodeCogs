from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates admin user with shared credentials'

    def handle(self, *args, **options):
        # Shared admin credentials
        username = 'admin'
        password = 'admin@auditra2024'
        email = 'admin@auditra.com'
        
        # Check if admin already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(
                f'Admin user "{username}" already exists!'
            ))
            admin_user = User.objects.get(username=username)
        else:
            # Create admin user
            admin_user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='System',
                last_name='Administrator',
                is_staff=True,
                is_superuser=True
            )
            self.stdout.write(self.style.SUCCESS(
                f'Successfully created admin user: {username}'
            ))
        
        # Assign admin role
        user_role, created = UserRole.objects.get_or_create(user=admin_user)
        user_role.role = 'admin'
        user_role.save()
        
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'ADMIN CREDENTIALS (Share these with authorized admins):'
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
            'Admin user is ready to assign roles to other users!'
        ))

