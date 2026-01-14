from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import datetime, time, timedelta


class Holiday(models.Model):
    """Sri Lankan public holidays"""
    name = models.CharField(max_length=200)
    date = models.DateField(unique=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'holidays'
        verbose_name = 'Holiday'
        verbose_name_plural = 'Holidays'
        ordering = ['date']
    
    def __str__(self):
        return f"{self.name} - {self.date}"


class Attendance(models.Model):
    """Attendance tracking for field officers"""
    
    STATUS_CHOICES = [
        ('present', 'Present'),
        ('half_day', 'Half Day'),
        ('absent', 'Absent'),
        ('leave', 'On Leave'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='attendances')
    date = models.DateField()
    
    # Regular working hours (8 AM - 5 PM)
    check_in = models.DateTimeField(null=True, blank=True)
    check_out = models.DateTimeField(null=True, blank=True)
    
    # Overtime hours (after 5 PM)
    overtime_start = models.DateTimeField(null=True, blank=True)
    overtime_end = models.DateTimeField(null=True, blank=True)
    
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='absent')
    
    # Calculated fields
    working_hours = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)  # Hours worked (8 AM - 5 PM)
    overtime_hours = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)  # Overtime hours
    
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'attendances'
        verbose_name = 'Attendance'
        verbose_name_plural = 'Attendances'
        unique_together = ['user', 'date']
        ordering = ['-date', '-check_in']
    
    def __str__(self):
        return f"{self.user.username} - {self.date} - {self.get_status_display()}"
    
    def calculate_working_hours(self):
        """Calculate working hours from check_in to check_out"""
        if self.check_in and self.check_out:
            # Ensure check_out is after check_in
            if self.check_out < self.check_in:
                return 0.0
            
            # Normalize check-in to 8 AM if it's earlier
            effective_start_time = time(8, 0)
            local_check_in = timezone.localtime(self.check_in)
            
            if local_check_in.time() < effective_start_time:
                # Create a new datetime with the same date but set to 8 AM local time
                start_dt = datetime.combine(local_check_in.date(), effective_start_time)
                # Make it aware again using the current timezone
                effective_check_in = timezone.make_aware(start_dt, timezone.get_current_timezone())
            else:
                effective_check_in = self.check_in
                
            # Normalize check-out to 5 PM if it's later (regular working hours)
            effective_end_time = time(17, 0)
            local_check_out = timezone.localtime(self.check_out)
            
            if local_check_out.time() > effective_end_time:
                end_dt = datetime.combine(local_check_out.date(), effective_end_time)
                effective_check_out = timezone.make_aware(end_dt, timezone.get_current_timezone())
            else:
                effective_check_out = self.check_out
            
            if effective_check_out < effective_check_in:
                return 0.0
                
            duration = effective_check_out - effective_check_in
            hours = duration.total_seconds() / 3600
            return max(0.0, float(hours))
        return 0.0
    
    def calculate_overtime_hours(self):
        """Calculate overtime hours"""
        if self.overtime_start and self.overtime_end:
            # Ensure overtime_end is after overtime_start
            if self.overtime_end < self.overtime_start:
                return 0.0
            duration = self.overtime_end - self.overtime_start
            hours = duration.total_seconds() / 3600
            # Ensure hours are not negative
            return max(0.0, hours)
        return 0.0
    
    def is_full_day(self):
        """Check if it's a full day (at least 4.5 hours)"""
        return self.working_hours >= 4.5
    
    def save(self, *args, **kwargs):
        # If status is absent, clear check_in and check_out times
        if self.status == 'absent':
            self.check_in = None
            self.check_out = None
            self.working_hours = 0.0
            self.overtime_start = None
            self.overtime_end = None
            self.overtime_hours = 0.0
        else:
            # Calculate working hours
            if self.check_in and self.check_out:
                # Check if check_out is before check_in (invalid time range)
                if self.check_out < self.check_in:
                    # Invalid time range - set to absent
                    self.working_hours = 0.0
                    self.status = 'absent'
                    self.check_in = None
                    self.check_out = None
                else:
                    self.working_hours = self.calculate_working_hours()
                    
                    # Determine status based on check-out time (LOCAL TIME)
                    local_check_out = timezone.localtime(self.check_out)
                    checkout_time = local_check_out.time()
                    
                    if checkout_time < time(12, 0):
                        self.status = 'absent'
                    elif checkout_time < time(17, 0):
                        self.status = 'half_day'
                    else:
                        self.status = 'present'
            elif self.check_in and not self.check_out:
                # Only checked in, not checked out yet
                self.working_hours = 0.0
                # Don't change status if already set (might be present from check-in)
                if not self.status or self.status == 'absent':
                    self.status = 'present'
            else:
                # If no check_in or check_out, set working hours to 0
                self.working_hours = 0.0
                # Only set to absent if status wasn't explicitly set (e.g., auto-marked absent)
                if not self.status:
                    self.status = 'absent'
            
            # Calculate overtime hours
            if self.overtime_start and self.overtime_end:
                # Check if overtime_end is before overtime_start (invalid time range)
                if self.overtime_end < self.overtime_start:
                    self.overtime_hours = 0.0
                else:
                    self.overtime_hours = self.calculate_overtime_hours()
                    # Ensure overtime hours are never negative
                    self.overtime_hours = max(0.0, float(self.overtime_hours))
            else:
                # If no overtime_start or overtime_end, set overtime hours to 0
                self.overtime_hours = 0.0
        
        super().save(*args, **kwargs)
    
    @staticmethod
    def is_working_day(date):
        """Check if a date is a working day (not Sunday and not a holiday)"""
        # Check if it's Sunday
        if date.weekday() == 6:  # Sunday is 6
            return False
        
        # Check if it's a holiday
        if Holiday.objects.filter(date=date, is_active=True).exists():
            return False
        
        return True

