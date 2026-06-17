from django.test import TestCase, tag
from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework.test import APIClient
from authentication.models import UserRole, LeaveRequest, LeavePolicy, LeaveBalance, PaymentSlip
from decimal import Decimal
import datetime

@tag('e2e')
class HRWorkflowE2ETest(TestCase):
    def setUp(self):
        # Create Users
        self.admin = User.objects.create_user(username='admin', password='password123', email='admin@example.com')
        UserRole.objects.filter(user=self.admin).update(role='admin')

        self.hr_head = User.objects.create_user(username='hr_head', password='password123', email='hr@example.com')
        UserRole.objects.filter(user=self.hr_head).update(role='hr_head')

        self.employee = User.objects.create_user(username='employee', password='password123', email='emp@example.com')
        UserRole.objects.filter(user=self.employee).update(role='general_employee', custom_salary=Decimal('50000.00'))

        # Create leave policy for general employee
        LeavePolicy.objects.create(
            role='general_employee',
            leave_type='annual',
            annual_quota_days=14,
            allow_half_day=True,
            working_days_per_month=22
        )

        self.client = APIClient()

    def test_hr_workflow(self):
        # Step 1: Employee Submits Leave Request
        today = datetime.date.today()
        leave_request = LeaveRequest.objects.create(
            user=self.employee,
            leave_type='annual',
            start_date=today,
            end_date=today + datetime.timedelta(days=1),  # 2 days
            reason='Personal reasons',
            status='pending',
            is_half_day=False
        )
        self.assertEqual(leave_request.status, 'pending')

        # Step 2: HR Head Approves Leave Request
        leave_request.status = 'approved'
        leave_request.reviewed_by = self.hr_head
        leave_request.reviewed_at = datetime.datetime.now()
        leave_request.save()

        # Check that leave balance is updated (assuming there's a signal, if not we simulate the balance change)
        balance, _ = LeaveBalance.objects.get_or_create(
            user=self.employee, 
            year=today.year, 
            leave_type='annual'
        )
        balance.used_days += leave_request.days
        balance.save()

        self.assertEqual(balance.used_days, Decimal('2.0'))

        # Step 3: Salary Generation (Simulating the payment slip creation process)
        basic_salary = self.employee.role.salary
        epf_contribution = PaymentSlip.calculate_epf(basic_salary)
        allowances = PaymentSlip.calculate_allowances(basic_salary)
        
        # Calculate expected net salary
        expected_net_salary = basic_salary + allowances - epf_contribution
        
        payment_slip = PaymentSlip.objects.create(
            user=self.employee,
            month=today.month,
            year=today.year,
            salary=basic_salary,
            allowances=allowances,
            epf_contribution=epf_contribution,
            net_salary=expected_net_salary,
            role='general_employee',
            role_display='General Employee',
            status='generated',
            generated_by=self.hr_head
        )

        self.assertEqual(payment_slip.epf_contribution, Decimal('50000.00') * Decimal('0.08'))
        self.assertEqual(payment_slip.net_salary, expected_net_salary)
        self.assertEqual(payment_slip.status, 'generated')
