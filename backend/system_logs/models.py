import hashlib
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone


ACTION_CHOICES = [
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
    ('ATTENDANCE_CHECK_IN', 'Attendance Check In'),
    ('ATTENDANCE_CHECK_OUT', 'Attendance Check Out'),
    ('ATTENDANCE_OVERTIME_START', 'Overtime Started'),
    ('ATTENDANCE_OVERTIME_END', 'Overtime Ended'),
    ('VALUATION_CREATED', 'Valuation Created'),
    ('VALUATION_UPDATED', 'Valuation Updated'),
    ('VALUATION_SUBMITTED', 'Valuation Submitted'),
    ('VALUATION_ACCEPTED', 'Valuation Accepted'),
    ('VALUATION_REJECTED', 'Valuation Rejected'),
    ('VALUATION_APPROVED', 'Valuation Approved'),
]

CATEGORY_CHOICES = [
    ('auth', 'Authentication'),
    ('user', 'User Management'),
    ('project', 'Projects'),
    ('payment', 'Payments'),
    ('leave', 'Leave Management'),
    ('removal', 'Employee Removal'),
    ('submission', 'Form Submissions'),
    ('attendance', 'Attendance'),
    ('valuation', 'Valuations'),
    ('system', 'System'),
]


class SystemLog(models.Model):
    block_index = models.PositiveIntegerField(unique=True, db_index=True)
    action = models.CharField(max_length=50, choices=ACTION_CHOICES)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='system')
    user = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.DO_NOTHING,
        related_name='system_logs', help_text='User who performed the action'
    )
    target_user = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.DO_NOTHING,
        related_name='targeted_logs', help_text='User affected by the action'
    )
    description = models.TextField()
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    metadata = models.JSONField(null=True, blank=True)
    timestamp = models.DateTimeField(default=timezone.now, db_index=True)
    previous_hash = models.CharField(max_length=64)
    current_hash = models.CharField(max_length=64)

    class Meta:
        ordering = ['block_index']

    def __str__(self):
        return f"[{self.block_index}] {self.action}"

    def compute_hash(self):
        data = (
            f"{self.block_index}"
            f"{self.action}"
            f"{self.user_id or 'system'}"
            f"{self.description}"
            f"{self.timestamp.isoformat()}"
            f"{self.previous_hash}"
        )
        return hashlib.sha256(data.encode('utf-8')).hexdigest()
