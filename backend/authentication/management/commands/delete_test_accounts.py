from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Deletes test accounts: field, client, and agent'

    def handle(self, *args, **options):
        usernames_to_delete = ['field', 'client', 'agent']
        
        deleted_count = 0
        not_found = []
        
        for username in usernames_to_delete:
            try:
                user = User.objects.get(username=username)
                # Get role info before deletion for logging
                role_info = ""
                if hasattr(user, 'role'):
                    role_info = f" (Role: {user.role.get_role_display()})"
                
                # Delete the user (UserRole will be deleted automatically due to CASCADE)
                user.delete()
                deleted_count += 1
                self.stdout.write(self.style.SUCCESS(
                    f'Successfully deleted user: {username}{role_info}'
                ))
            except User.DoesNotExist:
                not_found.append(username)
                self.stdout.write(self.style.WARNING(
                    f'User "{username}" does not exist, skipping...'
                ))
        
        # Summary
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'DELETION SUMMARY:'
        ))
        self.stdout.write(self.style.SUCCESS(
            '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            f'Deleted: {deleted_count} account(s)'
        ))
        if not_found:
            self.stdout.write(self.style.WARNING(
                f'Not found: {", ".join(not_found)}'
            ))
        self.stdout.write(self.style.SUCCESS(
            '='*50 + '\n'
        ))

