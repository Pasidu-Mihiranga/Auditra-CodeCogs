from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates agent user with specified credentials'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            default='agent',
            help='Username for the agent account'
        )
        parser.add_argument(
            '--password',
            type=str,
            default='agent123',
            help='Password for the agent account'
        )
        parser.add_argument(
            '--email',
            type=str,
            default='agent@auditra.com',
            help='Email for the agent account'
        )

    def handle(self, *args, **options):
        username = options['username']
        password = options['password']
        email = options['email']
        
        # Check if agent already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(
                f'Agent user "{username}" already exists!'
            ))
            agent_user = User.objects.get(username=username)
        else:
            # Create agent user
            agent_user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='Agent',
                last_name='User',
            )
            self.stdout.write(self.style.SUCCESS(
                f'Successfully created agent user: {username}'
            ))
        
        # Assign agent role
        user_role, created = UserRole.objects.get_or_create(user=agent_user)
        user_role.role = 'agent'
        user_role.save()
        
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'AGENT CREDENTIALS:'
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
            f'Agent role assigned successfully!'
        ))

