from rest_framework import serializers
from .models import SystemLog


class SystemLogSerializer(serializers.ModelSerializer):
    user_username = serializers.SerializerMethodField()
    user_full_name = serializers.SerializerMethodField()
    target_user_username = serializers.SerializerMethodField()
    action_display = serializers.CharField(source='get_action_display', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = SystemLog
        fields = (
            'id', 'block_index', 'action', 'action_display',
            'category', 'category_display',
            'user', 'user_username', 'user_full_name',
            'target_user', 'target_user_username',
            'description', 'ip_address', 'metadata',
            'timestamp', 'previous_hash', 'current_hash',
        )

    def _get_user_safe(self, obj):
        """Safely get the user object, handling dangling FKs from deleted users."""
        if obj.user_id is None:
            return None
        try:
            return obj.user
        except Exception:
            return None

    def _get_target_user_safe(self, obj):
        """Safely get the target_user object, handling dangling FKs."""
        if obj.target_user_id is None:
            return None
        try:
            return obj.target_user
        except Exception:
            return None

    def get_user_username(self, obj):
        user = self._get_user_safe(obj)
        if user:
            return user.username
        return None

    def get_user_full_name(self, obj):
        user = self._get_user_safe(obj)
        if user:
            name = f"{user.first_name} {user.last_name}".strip()
            return name or user.username
        # Check metadata for attempted_username (failed logins)
        if obj.metadata and isinstance(obj.metadata, dict):
            attempted = obj.metadata.get('attempted_username')
            if attempted:
                return f"{attempted} (failed)"
        # If user_id exists but user was deleted, show that
        if obj.user_id is not None:
            return f"Deleted User (ID: {obj.user_id})"
        return 'System'

    def get_target_user_username(self, obj):
        user = self._get_target_user_safe(obj)
        if user:
            return user.username
        return None
