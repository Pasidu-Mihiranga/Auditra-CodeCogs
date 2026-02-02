import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='SystemLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('block_index', models.PositiveIntegerField(db_index=True, unique=True)),
                ('action', models.CharField(choices=[
                    ('USER_LOGIN', 'User Login'),
                    ('USER_LOGOUT', 'User Logout'),
                    ('USER_REGISTER', 'User Registration'),
                    ('USER_DELETE', 'User Deleted'),
                    ('ROLE_ASSIGNED', 'Role Assigned'),
                    ('PASSWORD_CHANGED', 'Password Changed'),
                    ('PROJECT_CREATED', 'Project Created'),
                    ('PROJECT_UPDATED', 'Project Updated'),
                    ('PROJECT_APPROVED', 'Project Approved'),
                    ('PROJECT_REJECTED', 'Project Rejected'),
                    ('FIELD_OFFICER_ASSIGNED', 'Field Officer Assigned'),
                    ('CLIENT_ASSIGNED', 'Client Assigned'),
                    ('AGENT_ASSIGNED', 'Agent Assigned'),
                    ('ACCESSOR_ASSIGNED', 'Accessor Assigned'),
                    ('SENIOR_VALUER_ASSIGNED', 'Senior Valuer Assigned'),
                    ('PAYMENT_GENERATED', 'Payment Slips Generated'),
                    ('PAYMENT_UPLOADED', 'Payment Slips Published'),
                    ('LEAVE_CREATED', 'Leave Request Created'),
                    ('LEAVE_APPROVED', 'Leave Request Approved'),
                    ('LEAVE_REJECTED', 'Leave Request Rejected'),
                    ('REMOVAL_CREATED', 'Removal Request Created'),
                    ('REMOVAL_APPROVED', 'Removal Request Approved'),
                    ('REMOVAL_REJECTED', 'Removal Request Rejected'),
                    ('CLIENT_FORM_SUBMITTED', 'Client Form Submitted'),
                    ('EMPLOYEE_FORM_SUBMITTED', 'Employee Form Submitted'),
                    ('COORDINATOR_ASSIGNED', 'Coordinator Assigned to Submission'),
                    ('EMPLOYEE_CREATED', 'Employee Account Created'),
                    ('DOCUMENT_UPLOADED', 'Document Uploaded'),
                    ('CHAIN_VERIFIED', 'Chain Integrity Verified'),
                ], max_length=50)),
                ('category', models.CharField(choices=[
                    ('auth', 'Authentication'),
                    ('user', 'User Management'),
                    ('project', 'Projects'),
                    ('payment', 'Payments'),
                    ('leave', 'Leave Management'),
                    ('removal', 'Employee Removal'),
                    ('submission', 'Form Submissions'),
                    ('system', 'System'),
                ], default='system', max_length=20)),
                ('description', models.TextField()),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True)),
                ('metadata', models.JSONField(blank=True, null=True)),
                ('timestamp', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('previous_hash', models.CharField(max_length=64)),
                ('current_hash', models.CharField(max_length=64)),
                ('user', models.ForeignKey(blank=True, help_text='User who performed the action', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='system_logs', to=settings.AUTH_USER_MODEL)),
                ('target_user', models.ForeignKey(blank=True, help_text='User affected by the action', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='targeted_logs', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['block_index'],
            },
        ),
    ]
