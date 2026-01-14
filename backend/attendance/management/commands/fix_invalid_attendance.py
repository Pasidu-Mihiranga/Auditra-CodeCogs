from django.core.management.base import BaseCommand
from attendance.models import Attendance
from django.utils import timezone


class Command(BaseCommand):
    help = 'Fix attendance records where check_out is before check_in but status is still present'

    def handle(self, *args, **options):
        # Find all attendances with both check_in and check_out
        attendances = Attendance.objects.filter(
            check_in__isnull=False,
            check_out__isnull=False
        )
        
        total_fixed = 0
        
        for attendance in attendances:
            needs_fix = False
            old_status = attendance.status
            old_working_hours = attendance.working_hours
            
            # Check if check_out is before check_in (invalid time range)
            if attendance.check_out < attendance.check_in:
                needs_fix = True
                attendance.status = 'absent'
                attendance.working_hours = 0.0
                self.stdout.write(
                    f'  Fixed attendance {attendance.id} (user: {attendance.user.username}, '
                    f'date: {attendance.date}):\n'
                    f'    Check-in: {attendance.check_in}, Check-out: {attendance.check_out}\n'
                    f'    Status: {old_status} -> {attendance.status}\n'
                    f'    Working Hours: {old_working_hours} -> {attendance.working_hours}'
                )
            # Check if working_hours is 0 but status is still present
            elif attendance.working_hours == 0.0 and attendance.status == 'present':
                needs_fix = True
                attendance.status = 'absent'
                self.stdout.write(
                    f'  Fixed attendance {attendance.id} (user: {attendance.user.username}, '
                    f'date: {attendance.date}):\n'
                    f'    Status: {old_status} -> {attendance.status} (working_hours is 0.0)'
                )
            
            if needs_fix:
                attendance.save()
                total_fixed += 1
        
        if total_fixed == 0:
            self.stdout.write('No invalid attendance records found')
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    f'\nSuccessfully fixed {total_fixed} attendance record(s)'
                )
            )

