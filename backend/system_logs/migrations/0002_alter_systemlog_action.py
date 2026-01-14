from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('system_logs', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='systemlog',
            name='action',
            field=models.CharField(choices=[
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
                ('SUBMISSION_STATUS_UPDATED', 'Submission Status Updated'),
                ('EMPLOYEE_CREATED', 'Employee Account Created'),
                ('DOCUMENT_UPLOADED', 'Document Uploaded'),
                ('CHAIN_VERIFIED', 'Chain Integrity Verified'),
            ], max_length=50),
        ),
    ]
