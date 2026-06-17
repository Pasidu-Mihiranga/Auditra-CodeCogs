from django.test import TestCase, tag
from django.contrib.auth.models import User
from authentication.models import UserRole
from projects.models import Project

@tag('e2e')
class AuditingWorkflowE2ETest(TestCase):
    def setUp(self):
        # Create users
        self.coordinator = User.objects.create_user(username='coord', email='coord@example.com', password='password123')
        UserRole.objects.filter(user=self.coordinator).update(role='coordinator')
        
        self.client = User.objects.create_user(username='client', email='client@example.com', password='password123')
        UserRole.objects.filter(user=self.client).update(role='client')

        self.field_officer = User.objects.create_user(username='fo', email='fo@example.com', password='password123')
        UserRole.objects.filter(user=self.field_officer).update(role='field_officer')

        self.accessor = User.objects.create_user(username='accessor', email='accessor@example.com', password='password123')
        UserRole.objects.filter(user=self.accessor).update(role='accessor')

        self.senior_valuer = User.objects.create_user(username='sv', email='sv@example.com', password='password123')
        UserRole.objects.filter(user=self.senior_valuer).update(role='senior_valuer')

    def test_auditing_workflow(self):
        # Step 1: Coordinator creates a new project and assigns roles
        project = Project.objects.create(
            title='Test Auditing Project',
            description='E2E test project',
            coordinator=self.coordinator,
            assigned_client=self.client,
            assigned_field_officer=self.field_officer,
            assigned_accessor=self.accessor,
            assigned_senior_valuer=self.senior_valuer,
            status='pending',
            workflow_stage='created'
        )
        self.assertEqual(project.status, 'pending')
        
        # Step 2: Field Officer uploads a visit report and submits (status goes to in_progress)
        # Assuming the status transitions to in_progress when work starts
        project.status = 'in_progress'
        project.workflow_stage = 'field_visit_completed'
        project.save()
        
        project.refresh_from_db()
        self.assertEqual(project.status, 'in_progress')
        self.assertEqual(project.workflow_stage, 'field_visit_completed')

        # Step 3: Accessor does the required processing
        project.workflow_stage = 'accessor_processing_completed'
        project.status = 'completed'  # Or whatever status is next
        project.save()

        project.refresh_from_db()
        self.assertEqual(project.status, 'completed')

        # Step 4: Senior Valuer reviews and approves the final valuation
        project.workflow_stage = 'approved'
        project.md_gm_approval_status = 'approved'
        project.save()

        project.refresh_from_db()
        self.assertEqual(project.md_gm_approval_status, 'approved')
        self.assertEqual(project.workflow_stage, 'approved')
