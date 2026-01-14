from django.urls import path
from .views import SystemLogListView, VerifyChainView

urlpatterns = [
    path('', SystemLogListView.as_view(), name='system-log-list'),
    path('verify/', VerifyChainView.as_view(), name='verify-chain'),
]
