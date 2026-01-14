from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Attendance, Holiday


class AttendanceSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    user_full_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Attendance
        fields = (
            'id', 'user', 'user_username', 'user_full_name', 'date',
            'check_in', 'check_out', 'overtime_start', 'overtime_end',
            'status', 'status_display', 'working_hours', 'overtime_hours',
            'notes', 'created_at', 'updated_at'
        )
        read_only_fields = ('working_hours', 'overtime_hours', 'created_at', 'updated_at')
    
    def get_user_full_name(self, obj):
        if obj.user.first_name or obj.user.last_name:
            return f"{obj.user.first_name} {obj.user.last_name}".strip()
        return obj.user.username


class AttendanceSummarySerializer(serializers.Serializer):
    """Serializer for attendance summary statistics"""
    total_days = serializers.IntegerField()
    present_days = serializers.IntegerField()
    half_days = serializers.IntegerField()
    absent_days = serializers.IntegerField()
    total_working_hours = serializers.DecimalField(max_digits=10, decimal_places=2)
    total_overtime_hours = serializers.DecimalField(max_digits=10, decimal_places=2)
    attendance_percentage = serializers.DecimalField(max_digits=5, decimal_places=2)


class HolidaySerializer(serializers.ModelSerializer):
    class Meta:
        model = Holiday
        fields = ('id', 'name', 'date', 'is_active', 'created_at')
        read_only_fields = ('created_at',)

