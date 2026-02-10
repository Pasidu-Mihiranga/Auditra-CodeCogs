from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from projects.models import Project, ProjectStatusHistory
from valuations.models import Valuation
from authentication.models import UserRole
from django.utils import timezone
from datetime import timedelta
import random

class Command(BaseCommand):
    help = 'Populate mock data for projects, status history, and valuations'

    def handle(self, *args, **options):
        self.stdout.write('Starting mock data population...')

        # 1. Ensure users for each role exist
        roles = ['coordinator', 'field_officer', 'client', 'agent', 'accessor', 'senior_valuer']
        users = {}

        for role_name in roles:
            username = f'mock_{role_name}'
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': f'{username}@example.com',
                    'first_name': f'Mock',
                    'last_name': role_name.replace('_', ' ').title()
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            
            # Ensure correct role
            user_role, role_created = UserRole.objects.get_or_create(user=user)
            user_role.role = role_name
            user_role.save()
            
            users[role_name] = user
            self.stdout.write(f'User ready: {username} ({role_name})')

        # 2. Define Scenarios
        scenarios = [
            {
                'title': 'Commercial Complex Valuation - Colombo 03',
                'description': 'Valuation of a 5-story commercial building and land in Colombo 03 for mortgage purposes.',
                'status': 'completed',
                'priority': 'high',
                'history': [
                    ('pending', 'Project created', users['coordinator'], -10),
                    ('pending', 'Client assigned: Mock Client', users['coordinator'], -9),
                    ('pending', 'Field Officer assigned: Mock Field Officer', users['coordinator'], -8),
                    ('pending', 'Accessor assigned: Mock Accessor', users['coordinator'], -7),
                    ('pending', 'Senior Valuer assigned: Mock Senior Valuer', users['coordinator'], -6),
                    ('in_progress', 'Project started and assigned to Field Officer', users['coordinator'], -5),
                    ('in_progress', 'Valuation report submitted by Field Officer', users['field_officer'], -4),
                    ('in_progress', 'Valuation (Building) accepted by Accessor and sent to Senior Valuer for approval.', users['accessor'], -3),
                    ('in_progress', 'Valuation (Land) accepted by Accessor and sent to Senior Valuer for approval.', users['accessor'], -3),
                    ('completed', 'Valuation (Building) approved by Senior Valuer.', users['senior_valuer'], -1),
                    ('completed', 'Valuation (Land) approved by Senior Valuer.', users['senior_valuer'], -1),
                ],
                'valuations': [
                    ('building', 'approved', 'Excellent structure, well maintained.', 45000000),
                    ('land', 'approved', 'Prime location in Colombo 03.', 120000000),
                ]
            },
            {
                'title': 'Residential Property - Kandy',
                'description': 'Valuation of a residential house and property in Kandy.',
                'status': 'in_progress',
                'priority': 'medium',
                'history': [
                    ('pending', 'Project created', users['coordinator'], -5),
                    ('pending', 'Client assigned: Mock Client', users['coordinator'], -4),
                    ('in_progress', 'Project started', users['coordinator'], -3),
                    ('in_progress', 'Valuation report submitted by Field Officer', users['field_officer'], -2),
                ],
                'valuations': [
                    ('building', 'submitted', 'Standard residential building.', 15000000),
                ]
            },
            {
                'title': 'Vehicle Valuation - Toyota Prius',
                'description': 'Market value assessment of a Toyota Prius 2018 model.',
                'status': 'in_progress',
                'priority': 'low',
                'history': [
                    ('pending', 'Project created', users['coordinator'], -2),
                    ('in_progress', 'Project started', users['coordinator'], -1),
                    ('in_progress', 'Valuation (Vehicle) rejected by Senior Valuer. Reason: Photos are unclear.', users['senior_valuer'], 0),
                ],
                'valuations': [
                    ('vehicle', 'rejected', 'Vehicle in good condition.', 8500000, 'Photos are unclear.'),
                ]
            }
        ]

        # 3. Create Projects and History
        for s in scenarios:
            project = Project.objects.create(
                title=s['title'],
                description=s['description'],
                status=s['status'],
                priority=s['priority'],
                coordinator=users['coordinator'],
                assigned_field_officer=users['field_officer'],
                assigned_client=users['client'],
                assigned_accessor=users['accessor'],
                assigned_senior_valuer=users['senior_valuer'],
            )

            # Manually set history entries with adjusted timestamps
            now = timezone.now()
            for status, notes, user, days_ago in s['history']:
                hist = ProjectStatusHistory.objects.create(
                    project=project,
                    status=status,
                    notes=notes,
                    created_by=user
                )
                # Overwrite auto_now_add timestamp
                hist.created_at = now + timedelta(days=days_ago)
                hist.save()

            # Create Valuations
            for category, status, notes, estimated_value, *rejection in s.get('valuations', []):
                rej_reason = rejection[0] if rejection else ''
                Valuation.objects.create(
                    project=project,
                    field_officer=users['field_officer'],
                    category=category,
                    status=status,
                    notes=notes,
                    estimated_value=estimated_value,
                    rejection_reason=rej_reason,
                    senior_valuer_comments="Verified by mock senior valuer." if status == 'approved' else ""
                )

            self.stdout.write(self.style.SUCCESS(f'Created project: {project.title}'))

        self.stdout.write(self.style.SUCCESS('\nMock data population complete!'))
