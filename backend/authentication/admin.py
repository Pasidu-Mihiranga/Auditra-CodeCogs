from django.contrib import admin
from django.contrib.auth.models import User
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import UserRole, PaymentSlip


class UserRoleInline(admin.StackedInline):
    model = UserRole
    can_delete = False
    verbose_name_plural = 'Role'
    fk_name = 'user'


class UserAdmin(BaseUserAdmin):
    inlines = (UserRoleInline,)
    list_display = ('username', 'email', 'first_name', 'last_name', 'get_role', 'is_staff')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'role__role')
    
    def get_role(self, obj):
        return obj.role.get_role_display() if hasattr(obj, 'role') else 'N/A'
    get_role.short_description = 'Role'


# Unregister default User admin and register custom one
admin.site.unregister(User)
admin.site.register(User, UserAdmin)


@admin.register(UserRole)
class UserRoleAdmin(admin.ModelAdmin):
    list_display = ('user', 'role', 'assigned_by', 'assigned_at')
    list_filter = ('role', 'assigned_at')
    search_fields = ('user__username', 'user__email')
    readonly_fields = ('assigned_at', 'created_at')


@admin.register(PaymentSlip)
class PaymentSlipAdmin(admin.ModelAdmin):
    list_display = ('user', 'month', 'year', 'salary', 'role_display', 'status', 'generated_at')
    list_filter = ('status', 'month', 'year', 'role')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name')
    readonly_fields = ('generated_at', 'paid_at')
    date_hierarchy = 'generated_at'
