from django.contrib import admin
from .models import Project, ProjectDocument


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ('title', 'coordinator', 'assigned_field_officer', 'status', 'created_at')
    list_filter = ('status', 'coordinator', 'created_at')
    search_fields = ('title', 'description')
    date_hierarchy = 'created_at'
    readonly_fields = ('created_at', 'updated_at')


@admin.register(ProjectDocument)
class ProjectDocumentAdmin(admin.ModelAdmin):
    list_display = ('name', 'project', 'uploaded_by', 'uploaded_at')
    list_filter = ('uploaded_at', 'project')
    search_fields = ('name', 'description', 'project__title')
    date_hierarchy = 'uploaded_at'
    readonly_fields = ('uploaded_at',)

