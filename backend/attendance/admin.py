from django.contrib import admin
from .models import Attendance, Holiday


@admin.register(Holiday)
class HolidayAdmin(admin.ModelAdmin):
    list_display = ('name', 'date', 'is_active', 'created_at')
    list_filter = ('is_active', 'date')
    search_fields = ('name',)
    date_hierarchy = 'date'


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'status', 'check_in', 'check_out', 'working_hours', 'overtime_hours')
    list_filter = ('status', 'date', 'user')
    search_fields = ('user__username', 'user__email')
    date_hierarchy = 'date'
    readonly_fields = ('working_hours', 'overtime_hours', 'created_at', 'updated_at')

