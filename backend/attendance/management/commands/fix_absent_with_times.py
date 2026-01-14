from django.core.management.base import BaseCommand
from django.db.models import Q
from attendance.models import Attendance


class Command(BaseCommand):
    help = 'Fix attendance records where status is absent but they have check_in or check_out times'

    def handle(self, *args, **options):
        # Find all attendances with status 'absent' but have check_in or check_out
        absent_with_times = Attendance.objects.filter(
            status='absent'
        ).filter(
            Q(check_in__isnull=False) | Q(check_out__isnull=False)
        )
        
        total_fixed = 0
        
        if absent_with_times.exists():
            count = absent_with_times.count()
            self.stdout.write(f'Found {count} attendance(s) with absent status but have check-in/check-out times')
            
            for attendance in absent_with_times:
                had_check_in = attendance.check_in is not None
                had_check_out = attendance.check_out is not None
                had_overtime_start = attendance.overtime_start is not None
                had_overtime_end = attendance.overtime_end is not None
                
                # Clear all times for absent records
                attendance.check_in = None
                attendance.check_out = None
                attendance.overtime_start = None
                attendance.overtime_end = None
                attendance.working_hours = 0.0
                attendance.overtime_hours = 0.0
                attendance.save()
                
                total_fixed += 1
                cleared_items = []
                if had_check_in:
                    cleared_items.append('check_in')
                if had_check_out:
                    cleared_items.append('check_out')
                if had_overtime_start:
                    cleared_items.append('overtime_start')
                if had_overtime_end:
                    cleared_items.append('overtime_end')
                
                self.stdout.write(
                    f'  Fixed attendance {attendance.id} (user: {attendance.user.username}, '
                    f'date: {attendance.date}): Cleared {", ".join(cleared_items)}'
                )
        else:
            self.stdout.write('No attendances with absent status and check-in/check-out times found')
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\nSuccessfully fixed {total_fixed} attendance record(s)'
            )
        )

