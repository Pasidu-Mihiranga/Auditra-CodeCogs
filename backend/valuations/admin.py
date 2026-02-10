from django.contrib import admin
from .models import Valuation, ValuationPhoto


@admin.register(Valuation)
class ValuationAdmin(admin.ModelAdmin):
    list_display = ['id', 'project', 'field_officer', 'category', 'status', 'estimated_value', 'created_at']
    list_filter = ['category', 'status', 'created_at']
    search_fields = ['project__title', 'field_officer__username', 'description']
    readonly_fields = ['created_at', 'updated_at', 'submitted_at']


@admin.register(ValuationPhoto)
class ValuationPhotoAdmin(admin.ModelAdmin):
    list_display = ['id', 'valuation', 'caption', 'uploaded_at']
    list_filter = ['uploaded_at']
    search_fields = ['valuation__project__title', 'caption']
