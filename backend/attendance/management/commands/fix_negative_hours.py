from django.core.management.base import BaseCommand
from attendance.models import Attendance
from django.db.models import Q


class Command(BaseCommand):
    help = 'Fix negative working_hours and overtime_hours in the database'

    def handle(self, *args, **options):
        # Find all attendances with negative working_hours or overtime_hours
        negative_working = Attendance.objects.filter(working_hours__lt=0)
        negative_overtime = Attendance.objects.filter(overtime_hours__lt=0)
        
        total_fixed = 0
        
        # Fix negative working_hours
        if negative_working.exists():
            count = negative_working.count()
            self.stdout.write(f'Found {count} attendance(s) with negative working_hours')
            
            for attendance in negative_working:
                old_value = attendance.working_hours
                # Recalculate working hours
                attendance.working_hours = attendance.calculate_working_hours()
                # Ensure it's not negative
                attendance.working_hours = max(0.0, float(attendance.working_hours))
                attendance.save()
                total_fixed += 1
                self.stdout.write(
                    f'  Fixed attendance {attendance.id} (user: {attendance.user.username}, '
                    f'date: {attendance.date}): {old_value} -> {attendance.working_hours}'
                )
        else:
            self.stdout.write('No attendances with negative working_hours found')
        
        # Fix negative overtime_hours
        if negative_overtime.exists():
            count = negative_overtime.count()
            self.stdout.write(f'\nFound {count} attendance(s) with negative overtime_hours')
            
            for attendance in negative_overtime:
                old_value = attendance.overtime_hours
                # Recalculate overtime hours
                attendance.overtime_hours = attendance.calculate_overtime_hours()
                # Ensure it's not negative
                attendance.overtime_hours = max(0.0, float(attendance.overtime_hours))
                attendance.save()
                total_fixed += 1
                self.stdout.write(
                    f'  Fixed attendance {attendance.id} (user: {attendance.user.username}, '
                    f'date: {attendance.date}): {old_value} -> {attendance.overtime_hours}'
                )
        else:
            self.stdout.write('No attendances with negative overtime_hours found')
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\nSuccessfully fixed {total_fixed} attendance record(s)'
            )
        )

