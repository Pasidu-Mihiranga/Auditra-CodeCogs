from django.contrib import admin
from .models import SystemLog


@admin.register(SystemLog)
class SystemLogAdmin(admin.ModelAdmin):
    list_display = ('block_index', 'action', 'category', 'user', 'timestamp')
    list_filter = ('category', 'action')
    search_fields = ('description', 'user__username')
    readonly_fields = ('block_index', 'action', 'category', 'user', 'target_user',
                       'description', 'ip_address', 'metadata', 'timestamp',
                       'previous_hash', 'current_hash')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
