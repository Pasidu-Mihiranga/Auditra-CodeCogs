from django.urls import path

app_name = 'attendance'

# Import views with error handling
try:
    from . import views
    
    urlpatterns = [
        path('mark/', views.MarkAttendanceView.as_view(), name='mark-attendance'),
        path('leave-early/', views.LeaveEarlyView.as_view(), name='leave-early'),
        path('checkout/', views.CheckOutView.as_view(), name='checkout'),
        path('overtime/start/', views.StartOvertimeView.as_view(), name='start-overtime'),
        path('overtime/end/', views.EndOvertimeView.as_view(), name='end-overtime'),
        path('today/', views.TodayAttendanceView.as_view(), name='today-attendance'),
        path('summary/', views.AttendanceSummaryView.as_view(), name='attendance-summary'),
        path('summary/weekly/', views.WeeklyAttendanceSummaryView.as_view(), name='weekly-attendance-summary'),
        path('summary/hr/', views.HRAttendanceSummaryView.as_view(), name='hr-attendance-summary'),
        path('my-attendances/', views.MyAttendancesView.as_view(), name='my-attendances'),
    ]
except ImportError as e:
    print(f"ERROR: Failed to import attendance views: {e}")
    import traceback
    traceback.print_exc()
    urlpatterns = []
except Exception as e:
    print(f"ERROR: Failed to setup attendance URLs: {e}")
    import traceback
    traceback.print_exc()
    urlpatterns = []

