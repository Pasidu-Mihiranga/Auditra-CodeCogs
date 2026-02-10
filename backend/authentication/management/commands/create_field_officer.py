from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates field officer user with specified credentials'

    def handle(self, *args, **options):
        # Field officer credentials
        username = 'field'
        password = 'field123'
        email = 'field@auditra.com'
        
        # Check if field officer already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(
                f'Field officer user "{username}" already exists!'
            ))
            field_user = User.objects.get(username=username)
        else:
            # Create field officer user
            field_user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='Field',
                last_name='Officer',
            )
            self.stdout.write(self.style.SUCCESS(
                f'Successfully created field officer user: {username}'
            ))
        
        # Assign field officer role
        user_role, created = UserRole.objects.get_or_create(user=field_user)
        user_role.role = 'field_officer'
        user_role.save()
        
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'FIELD OFFICER CREDENTIALS:'
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
            f'Field officer role assigned successfully!'
        ))

