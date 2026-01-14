from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates client user with specified credentials'

    def handle(self, *args, **options):
        # Client credentials
        username = 'client'
        password = 'client123'
        email = 'client@auditra.com'
        
        # Check if client already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(
                f'Client "{username}" already exists!'
            ))
            client_user = User.objects.get(username=username)
            # Update name to remove "User"
            client_user.first_name = 'Client'
            client_user.last_name = ''
            client_user.save()
        else:
            # Create client
            client_user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='Client',
                last_name='',
            )
            self.stdout.write(self.style.SUCCESS(
                f'Successfully created client: {username}'
            ))
        
        # Assign client role
        user_role, created = UserRole.objects.get_or_create(user=client_user)
        user_role.role = 'client'
        user_role.save()
        
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'CLIENT CREDENTIALS:'
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
            f'Client role assigned successfully!'
        ))

