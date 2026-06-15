import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../services/offline_db_service.dart';
import '../services/offline_storage_service.dart';
import '../services/network_service.dart';
import '../models/attendance_model.dart';
import '../models/project_model.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'valuation_form_screen.dart';
import 'payment_slips_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
// import 'field_officer/components/field_officer_header.dart'; // Removed
import 'field_officer/components/field_officer_project_card.dart';
import 'field_officer/screens/project_details_screen.dart'; // Added
import 'field_officer/screens/valuation_reports_screen.dart'; // Added
import 'visit_scheduling_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/sync_status_indicator.dart';
import '../services/pdf_service.dart';
import '../models/valuation_model.dart';

/// The main dashboard screen for field officers.
/// It has two tabs: "Profile & Attendance" and "Projects".
/// Field officers use this screen to check in, view their projects,
/// create valuation reports, and submit them for review.
class FieldOfficerDashboard extends StatefulWidget {
  const FieldOfficerDashboard({super.key});

  @override
  State<FieldOfficerDashboard> createState() => _FieldOfficerDashboardState();
}

class _FieldOfficerDashboardState extends State<FieldOfficerDashboard> with TickerProviderStateMixin {
  // ─── State variables ─────────────────────────────────────────────────────

  Attendance? _todayAttendance; // Today's attendance record (null = not yet checked in)
  bool _isLoading = true;          // True while any data is being fetched
  bool _isWorkingDay = true;        // False on Sundays and public holidays
  String _selectedPeriod = 'daily'; // Period shown in the attendance summary
  AttendanceSummary? _summary;      // Attendance stats for the selected period
  bool _isLoadingSummary = false;
  bool _isMarkingAttendance = false; // True while the check-in API call is in progress
  String? _username;                 // Logged-in user's username
  String? _roleDisplay;              // Human-readable role (e.g. "Field Officer")

  // Project state
  List<Project> _projects = [];     // All projects assigned to this field officer
  bool _isLoadingProjects = false;
  int _currentIndex = 0;             // Current tab index for bottom navigation
  bool _isNavBarCollapsed = false;   // Collapses navigation bar to a small dynamic island on scroll
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'pending', 'in_progress', 'completed', 'cancelled'

  // Timer for countdown
  DateTime? _countdownEnd;          // Fixed to 5:00 PM today
  Duration _remainingTime = Duration.zero; // Time left until 5 PM

  // Leave statistics state
  Map<String, dynamic>? _leaveStatistics;
  bool _isLoadingLeaveStats = false;
  StreamSubscription<bool>? _networkSubscription; // Listens to internet connectivity changes
  bool _wasOnline = true; // Tracks the previous connectivity state to detect transitions

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Called once when the screen first opens.
  /// Loads the user's info and projects, and starts listening for network changes.
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadCachedProjectsOnStartup();
    _loadProjects();
    _loadTodayAttendance();
    _loadSummary();
    _setupNetworkAutoRefresh();
  }

  /// Called when the screen is removed from the widget tree.
  /// Cancels the network listener to free up memory and avoid memory leaks.
  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }

  // ─── Network ──────────────────────────────────────────────────────────────

  /// Starts listening for internet connectivity changes.
  /// When the device goes from offline back to online, this function
  /// automatically refreshes the projects, attendance, and summary data
  /// and shows a "Back online" message to the user.
  Future<void> _setupNetworkAutoRefresh() async {
    if (!NetworkService.isInitialized) {
      await NetworkService.init();
    }
    _wasOnline = NetworkService.isOnline;
    _networkSubscription = NetworkService.networkStatusStream.listen((isOnline) {
      if (!mounted) return;
      // Auto refresh only on offline -> online transition.
      if (!_wasOnline && isOnline) {
        _loadProjects();
        _loadTodayAttendance();
        _loadSummary();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back online. Data refreshed automatically.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _wasOnline = isOnline;
    });
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  /// Fetches the logged-in user's username and role from the API
  /// and stores them in state so the welcome header can display them.
  Future<void> _loadUserInfo() async {
    final username = await ApiService.getUsername();
    final roleResult = await ApiService.getMyRole();
    if (mounted) {
      setState(() {
        _username = username;
        if (roleResult['success']) {
          _roleDisplay = roleResult['data']['role_display'];
        }
      });
    }
  }

  // ─── Timer ────────────────────────────────────────────────────────────────

  /// Initialises the end-of-day countdown target to 5:00 PM today
  /// and immediately starts counting down.
  void _startTimer() {
    // Set countdown to 5 PM today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _countdownEnd = DateTime(today.year, today.month, today.day, 17, 0);
    
    // Update timer immediately
    _updateTimer();
  }

  /// Updates [_remainingTime] every second so the countdown display refreshes.
  /// When the timer reaches zero (5 PM), it automatically calls [_checkOut]
  /// if the field officer is still checked in.
  void _updateTimer() {
    if (_countdownEnd != null) {
      final now = DateTime.now();
      if (now.isBefore(_countdownEnd!)) {
        setState(() {
          _remainingTime = _countdownEnd!.difference(now);
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _updateTimer();
          }
        });
      } else {
        setState(() {
          _remainingTime = Duration.zero;
        });
        // Auto-checkout when countdown ends at 5 PM
        if (_todayAttendance != null && 
            _todayAttendance!.isCheckedIn && 
            !_todayAttendance!.isCheckedOut) {
          _checkOut();
        }
      }
    }
  }

  /// Fetches today's attendance record from the server.
  /// Updates [_todayAttendance] with check-in time, check-out time,
  /// working hours, and whether today is a working day.
  Future<void> _loadTodayAttendance() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getTodayAttendance();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final data = result['data'];
          _isWorkingDay = data['is_working_day'] ?? true;
          if (data['data'] != null) {
            _todayAttendance = Attendance.fromJson(data['data']);
          } else {
            _todayAttendance = null;
          }
        }
      });
      if (_todayAttendance != null && _todayAttendance!.isCheckedIn && !_todayAttendance!.isCheckedOut) {
        _startTimer();
      }
    }
  }

  /// Fetches attendance summary statistics (present days, absent days,
  /// total working hours, etc.) for the selected time period
  /// (daily / weekly / monthly / yearly).
  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    final result = await ApiService.getAttendanceSummary(period: _selectedPeriod);
    
    if (mounted) {
      setState(() {
        _isLoadingSummary = false;
        if (result['success'] && result['data']['data'] != null) {
          _summary = AttendanceSummary.fromJson(result['data']['data']);
        }
      });
    }
  }

  /// Fetches the list of projects assigned to this field officer from the server.
  /// If the server is unreachable, it falls back to the locally cached project list
  /// so the app still works offline.
  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _isLoadingProjects = true;
    });
    final result = await ApiService.getProjects();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingProjects = false;
        if (result['success']) {
          try {
            final data = result['data'] as List<dynamic>;
            _projects = data.map((p) => Project.fromJson(p)).toList();
            // Keep a local cache for offline project loading.
            OfflineStorageService.cacheProjects(_projects);
          } catch (e) {
            print('Error parsing projects: $e');
            print('Response data: ${result['data']}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading projects: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          final cached = OfflineStorageService.getCachedProjects();
          if (cached != null && cached.isNotEmpty) {
            _projects = cached;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline mode: showing cached projects.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            final rawMessage = (result['message'] ?? '').toString();
            final isNetworkError = rawMessage.contains('Connection error') ||
                rawMessage.contains('Network is unreachable') ||
                rawMessage.contains('Connection failed') ||
                rawMessage.contains('Failed host lookup');
            final message = isNetworkError
                ? 'You are offline. Projects will load when internet is back.'
                : 'Failed to load projects: ${result['message'] ?? 'Unknown error'}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    }
  }

  /// Loads projects from the local offline cache immediately when the screen opens.
  /// This makes the project list appear instantly, even before the server responds.
  /// The live data will replace it once [_loadProjects] finishes.
  Future<void> _loadCachedProjectsOnStartup() async {
    try {
      await OfflineDBService.initOfflineDB();
      final cached = OfflineStorageService.getCachedProjects();
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _projects = cached;
        });
      }
    } catch (_) {
      // Best-effort cache read; ignore and continue with live load.
    }
  }

  // ─── Navigation helpers ──────────────────────────────────────────────────

  /// Opens the Valuation Reports screen, which lists all valuation reports
  /// for the given [project]. Passes a callback so the project list
  /// refreshes when the user comes back.
  void _viewValuationReports(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ValuationReportsScreen(
          project: project,
          onProjectUpdated: _loadProjects,
        ),
      ),
    );
  }

  /// Opens the Valuation Form screen to create a brand-new valuation report
  /// for the given [project]. Reloads the project list on return.
  void _createReport(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ValuationFormScreen(project: project),
      ),
    ).then((_) => _loadProjects());
  }

  /// Asks the user to confirm, then submits all draft/rejected valuation reports
  /// for the given [project] to the accessor for review.
  ///
  /// For each report it:
  ///   1. Fetches the latest data from the server.
  ///   2. Generates a PDF report locally.
  ///   3. Uploads the PDF to the server.
  ///   4. Changes the report status to "submitted".
  ///
  /// Shows a success or error message when done.
  Future<void> _submitToAccessor(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit to Accessor'),
        content: Text(
          'Submit draft valuation report(s) for "${project.title}" to the accessor for review?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoadingProjects = true;
      });

      try {
        // Pull latest project details so we submit the newest draft/rejected valuations.
        final projectRes = await ApiService.getProject(project.id);
        if (projectRes['success'] != true) {
          throw Exception(projectRes['message'] ?? 'Failed to load latest project details');
        }
        final latestProject = Project.fromJson(projectRes['data']);
        final valuationsToSubmit = latestProject.valuations
            .where((v) => v.status == 'draft' || v.status == 'rejected')
            .toList();

        if (valuationsToSubmit.isEmpty) {
          if (mounted) {
            setState(() => _isLoadingProjects = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No draft reports to submit. Create or edit a valuation report first.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        int successCount = 0;
        int failedCount = 0;
        String? firstError;
        for (final valuation in valuationsToSubmit) {
          // Generate and upload PDF before changing status
          try {
            final valResult = await ApiService.getValuation(valuation.id);
            if (valResult['success'] == true && valResult['data'] != null) {
              final freshValuation = Valuation.fromJson(valResult['data']);
              final pdfFile = await PdfService.generateValuationReport(
                valuation: freshValuation,
                project: latestProject,
              );
              await ApiService.uploadSubmittedReport(valuation.id, pdfFile.path);
            }
          } catch (_) {
            // PDF generation is best-effort; proceed with submission
          }
          final submitRes = await ApiService.submitValuation(valuation.id);
          if (submitRes['success'] == true) {
            successCount++;
          } else {
            failedCount++;
            firstError ??= (submitRes['message'] ?? '').toString();
          }
        }
        
        if (mounted) {
          if (failedCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  successCount == 1
                      ? '1 valuation report submitted to accessor successfully'
                      : '$successCount valuation reports submitted to accessor successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
            // Reload projects to get updated status
            _loadProjects();
          } else {
            setState(() => _isLoadingProjects = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  successCount > 0
                      ? '$successCount submitted, $failedCount failed. ${firstError ?? ""}'.trim()
                      : 'Failed to submit reports: ${firstError ?? "Unknown error"}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingProjects = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting project: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─── Attendance actions ───────────────────────────────────────────────────

  /// Sends a check-in request to the server to mark attendance for today.
  /// Updates the local attendance record and starts the end-of-day countdown timer.
  /// Shows a success or error message depending on the API response.
  Future<void> _markAttendance() async {
    setState(() => _isMarkingAttendance = true);
    
    try {
      final result = await ApiService.markAttendance();
      
      if (mounted) {
        if (result['success']) {
          // Update attendance from response
          final responseData = result['data'];
          if (responseData != null && responseData['data'] != null) {
            setState(() {
              _todayAttendance = Attendance.fromJson(responseData['data']);
            });
            _startTimer();
          } else {
            // Fallback to reload
            await _loadTodayAttendance();
            _startTimer();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                   Icon(Icons.check_circle, color: Colors.white),
                   SizedBox(width: 8),
                   Expanded(child: Text('Attendance marked successfully!')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'] ?? 'Failed to mark attendance')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingAttendance = false);
      }
    }
  }

  /// Asks the user to confirm, then sends an early-leave request to the server.
  /// The backend records whether this counts as a full day or a half day
  /// based on how many hours were worked.
  Future<void> _leaveEarly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Early'),
        content: const Text('Are you sure you want to leave early?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.leaveEarly();
      
      if (mounted) {
        if (result['success']) {
          final data = result['data'];
          final isFullDay = data['is_full_day'] ?? false;
          final hours = data['working_hours'] ?? 0.0;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFullDay 
                  ? 'Full day recorded (${hours.toStringAsFixed(1)} hours)'
                  : 'Half day recorded (${hours.toStringAsFixed(1)} hours)'
              ),
            ),
          );
          _loadTodayAttendance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to mark early leave')),
          );
        }
      }
    }
  }

  /// Sends a check-out request to the server at the end of the working day.
  /// This is also called automatically when the 5 PM countdown reaches zero.
  Future<void> _checkOut() async {
    final result = await ApiService.checkOut();
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully!')),
        );
        _loadTodayAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to check out')),
        );
      }
    }
  }

  /// Sends a request to the server to begin recording overtime hours.
  /// Only available after the field officer has already checked out for the day.
  Future<void> _startOvertime() async {
    final result = await ApiService.startOvertime();
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overtime started!')),
        );
        _loadTodayAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to start overtime')),
        );
      }
    }
  }

  /// Sends a request to the server to stop recording overtime.
  /// The server returns the total overtime hours worked, which is shown
  /// in a snack bar and reflected in the attendance summary.
  Future<void> _endOvertime() async {
    final result = await ApiService.endOvertime();
    
    if (mounted) {
      if (result['success']) {
        final data = result['data'];
        final hours = data['overtime_hours'] ?? 0.0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Overtime ended! Total: ${hours.toStringAsFixed(1)} hours')),
        );
        _loadTodayAttendance();
        _loadSummary();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to end overtime')),
        );
      }
    }
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  /// Shows a styled confirmation dialog, then logs the user out.
  /// Clears the session token via the API and navigates back to the Login screen.
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.exit_to_app_rounded,
                      size: 64,
                      color: Colors.orange[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Are you sure?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are about to logout from your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 20),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Converts a [Duration] into a readable HH:MM:SS string.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
      extendBody: true,
      appBar: _buildAppBar(isDark),
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is ScrollUpdateNotification) {
              final scrollDelta = notification.scrollDelta ?? 0;
              if (scrollDelta > 10 && !_isNavBarCollapsed) {
                setState(() {
                  _isNavBarCollapsed = true;
                });
              } else if (scrollDelta < -10 && _isNavBarCollapsed) {
                setState(() {
                  _isNavBarCollapsed = false;
                });
              }
            }
            return false;
          },
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildDashboardTab(isDark),
              _buildProjectsTab(isDark),
              ProfileScreen(
                showAppBar: false,
                onNavigateToProjects: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    String title = '';
    List<Widget> actions = [const SyncStatusIndicator()];
    
    switch (_currentIndex) {
      case 0:
        title = 'Dashboard';
        actions.add(
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        );
        break;
      case 1:
        title = 'Projects';
        actions.add(
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        );
        break;
      case 2:
        title = 'My Profile';
        actions.add(
          IconButton(
            icon: Icon(Icons.logout_rounded, color: isDark ? Colors.white : Colors.black),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        );
        break;
    }

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 22,
          color: isDark ? Colors.white : const Color(0xFF111827),
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: actions,
    );
  }

  Widget _buildBottomNavigationBar(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 500 ? 450.0 : screenWidth;
    final collapsedWidth = 180.0;
    final expandedWidth = maxWidth - 48.0;
    
    final targetWidth = _isNavBarCollapsed ? collapsedWidth : expandedWidth;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.only(bottom: 24),
        width: targetWidth,
        height: _isNavBarCollapsed ? 54.0 : 68.0,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1E293B).withOpacity(0.7) 
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.08) 
                      : Colors.white.withOpacity(0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  final isSelected = _currentIndex == index;
                  final accentColor = AppColors.accent;
                  final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
                  final color = isSelected ? accentColor : unselectedColor;
                  
                  IconData iconData;
                  String label;
                  switch (index) {
                    case 0:
                      iconData = Icons.grid_view_rounded;
                      label = 'Dashboard';
                      break;
                    case 1:
                      iconData = Icons.assignment_rounded;
                      label = 'Projects';
                      break;
                    case 2:
                      iconData = Icons.person_rounded;
                      label = 'Profile';
                      break;
                    default:
                      iconData = Icons.grid_view_rounded;
                      label = '';
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              iconData,
                              size: _isNavBarCollapsed ? 22 : 20,
                              color: color,
                            ),
                            if (!_isNavBarCollapsed) ...[
                              const SizedBox(height: 3),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                  color: color,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the "Dashboard" tab (previously Profile & Attendance).
  /// Shows today's attendance card, the attendance summary, and quick-action links.
  /// Builds a calendar strip matching the clean, modern aesthetic of Image 2.
  Widget _buildCalendarStrip(bool isDark) {
    final now = DateTime.now();
    // Anchor the calendar strip so today is in the middle (index 3)
    final startOfStrip = now.subtract(const Duration(days: 3));
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final dayDate = startOfStrip.add(Duration(days: index));
          final isToday = dayDate.day == now.day && dayDate.month == now.month && dayDate.year == now.year;
          // Dynamically resolve weekday name based on the date
          final dayName = weekdays[dayDate.weekday - 1];
          final dayNumber = dayDate.day.toString();
          
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isToday 
                    ? AppColors.accent 
                    : (isDark ? const Color(0xFF1E293B) : Colors.transparent),
                borderRadius: BorderRadius.circular(20),
                border: !isToday && !isDark
                    ? Border.all(color: const Color(0xFFE5E7EB), width: 1)
                    : null,
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday 
                          ? Colors.white 
                          : (isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayNumber,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isToday 
                          ? Colors.white 
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Builds a modern quick action card with round border radius and a clean layout.
  Widget _buildQuickActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage settings',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the "Dashboard" tab (previously Profile & Attendance).
  /// Shows today's attendance card, the attendance summary, and quick-action links.
  Widget _buildDashboardTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hello Welcome section matching Image 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    _username ?? 'Officer',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar strip
          _buildCalendarStrip(isDark),
          const SizedBox(height: 20),

          // Today's Attendance
          _buildTodayAttendanceCard(),
          const SizedBox(height: 24),
          
          // Summary
          _buildSummarySection(),
          const SizedBox(height: 24),
          
          // Quick Actions title
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          
          // Row of Quick Action cards
          Row(
            children: [
              _buildQuickActionCard(
                icon: Icons.lock_reset_rounded,
                color: AppColors.accent,
                title: 'Change Password',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildQuickActionCard(
                icon: Icons.receipt_long_rounded,
                color: Colors.blue,
                title: 'Payment Slips',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentSlipsScreen(),
                    ),
                  );
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// Builds the "Projects" tab.
  /// Shows a search bar, filter chips, and a scrollable list of project cards.
  Widget _buildProjectsTab(bool isDark) {
    // Dynamic counts for chips
    final allCount = _projects.length;
    final pendingCount = _projects.where((p) => p.status == 'pending').length;
    final progressCount = _projects.where((p) => p.status == 'in_progress').length;
    final completedCount = _projects.where((p) => p.status == 'completed').length;
    final cancelledCount = _projects.where((p) => p.status == 'cancelled').length;

    // Filter projects locally based on search query and status filter
    final filtered = _projects.where((p) {
      final matchesSearch = p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatusFilter == 'all' || p.status == _selectedStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Column(
      children: [
        // Search Bar (Image 3 style)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: Colors.grey[400], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                    decoration: InputDecoration(
                      hintText: 'Search projects by location or ID...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),

        // Horizontal scrollable filter chips (Image 3 style)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Row(
            children: [
              _buildFilterChip('all', 'All ($allCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('pending', 'Pending ($pendingCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('in_progress', 'In Progress ($progressCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('completed', 'Completed ($completedCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('cancelled', 'Cancelled ($cancelledCount)'),
            ],
          ),
        ),

        // Projects list or empty state
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProjects,
            child: _isLoadingProjects
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyProjectsState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final project = filtered[index];
                          return FieldOfficerProjectCard(
                            project: project,
                            onViewDetails: _viewProjectDetails,
                            onViewReports: _viewValuationReports,
                            onCreateReport: _createReport,
                            onSubmit: _submitToAccessor,
                            onScheduleVisit: _openValuationSchedule,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterVal, String label) {
    final isSelected = _selectedStatusFilter == filterVal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = filterVal;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent // light blue variants
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF4B5563)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
  
  /// Builds the empty state shown in the Projects tab.
  Widget _buildEmptyProjectsState() {
    final hasNoAssignments = _projects.isEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            hasNoAssignments ? 'No projects assigned' : 'No projects found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasNoAssignments 
                ? 'Any projects assigned to you\nwill appear here automatically.'
                : 'Change your search query or status filter\nor pull to refresh live data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], height: 1.5),
          ),
        ],
      ),
    );
  }

  /// Navigates to the Project Details screen which shows full information
  /// about the selected [project] (description, visits, maps, etc.).
  Future<void> _viewProjectDetails(Project project) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailsScreen(project: project),
      ),
    );
  }

  /// Opens the Visit Scheduling screen so the field officer can set or update
  /// the date they plan to visit the site for the given [project].
  void _openValuationSchedule(Project project) {
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VisitSchedulingScreen(
          projectId: project.id,
          projectTitle: project.title,
          appBarTitle: 'Valuation schedule – ${project.title}',
          fabLabel: 'Set valuation date',
          emptyStateText:
              'No valuation date scheduled. Tap the button to choose when you will visit the site.',
          confirmDialogTitle: 'Confirm valuation date',
          confirmDialogScheduleLabel: 'Set date',
        ),
      ),
    )
        .then((_) {
      if (mounted) _loadProjects();
    });
  }
  
  // ─── Display helpers ─────────────────────────────────────────────────────

  /// Returns the colour associated with a project's priority level
  /// (red for high, blue for medium, green for low).
  Color _getPriorityColor(String priority) {
    return AppColors.priorityColor(priority);
  }
  
  /// Converts a raw priority string to an uppercase display label.
  /// Defaults to "MEDIUM" if the value is empty or unrecognised.
  String _formatPriorityLabel(String priority) {
    if (priority.isEmpty) return 'MEDIUM';
    final lower = priority.toLowerCase();
    if (lower == 'high') return 'HIGH';
    if (lower == 'low') return 'LOW';
    return 'MEDIUM';
  }
  
  /// Builds a small coloured badge (HIGH / MEDIUM / LOW) with an icon
  /// that is displayed on each project card.
  Widget _buildPriorityRibbon(String priority) {
    final color = _getPriorityColor(priority);
    final label = _formatPriorityLabel(priority);
    
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            priority.toLowerCase() == 'high'
                ? Icons.priority_high
                : priority.toLowerCase() == 'low'
                    ? Icons.arrow_downward
                    : Icons.remove_circle_outline,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a light background colour for a project status chip
  /// (orange for pending, blue for in-progress, green for completed, etc.).
  Color _getProjectStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[100]!;
      case 'in_progress':
        return Colors.blue[100]!;
      case 'completed':
        return Colors.green[100]!;
      case 'cancelled':
        return Colors.red[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  /// Returns the text/icon colour for a valuation report's status
  /// (grey for draft, blue for submitted, green for approved, red for rejected, etc.).
  Color _getValuationStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey[600]!;
      case 'submitted':
        return Colors.blue[600]!;
      case 'reviewed':
        return Colors.purple[600]!;
      case 'approved':
        return Colors.green[600]!;
      case 'rejected':
        return Colors.red[600]!;
      default:
        return Colors.grey[400]!;
    }
  }



  // ─── Attendance widgets ──────────────────────────────────────────────────

  /// Builds the "Today's Attendance" card at the top of the Profile tab.
  ///
  /// The card content changes based on the current state:
  ///   - Not a working day → shows an info message.
  ///   - Not yet checked in → shows the countdown timer + "Mark Attendance" button.
  ///   - Checked in but not out → shows the countdown timer + "Leave Early" button.
  ///   - Checked out → shows check-in/out times, working hours, and overtime controls.
  Widget _buildTodayAttendanceCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Today\'s Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            
            if (!_isWorkingDay)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3B2E1E) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: isDark ? Colors.amber[400] : Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Today is not a working day (Sunday or Holiday)',
                        style: TextStyle(
                          color: isDark ? Colors.amber[200] : Colors.orange[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_todayAttendance == null || !_todayAttendance!.isCheckedIn)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildAnimatedCountdown(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildAttendanceButton(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Working Hours: 8:00 AM - 5:00 PM',
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (_todayAttendance != null && _todayAttendance!.isCheckedIn && !_todayAttendance!.isCheckedOut)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildAnimatedCountdown(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: (DateTime.now().hour >= 17 || _remainingTime.inMinutes < 5)
                            ? _buildCheckOutButton()
                            : _buildLeaveEarlyButton(),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_todayAttendance!.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(_todayAttendance!.status).withOpacity(0.3)),
                        ),
                        child: Text(
                          _todayAttendance!.statusDisplay,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _getStatusColor(_todayAttendance!.status),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  if (_todayAttendance!.checkIn != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-in:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        Text(
                          DateFormat('hh:mm a').format(_todayAttendance!.checkIn!),
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  
                  if (_todayAttendance!.checkOut != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-out:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        Text(
                          DateFormat('hh:mm a').format(_todayAttendance!.checkOut!),
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Working Hours:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        Text(
                          '${_todayAttendance!.workingHours.toStringAsFixed(1)} hrs',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                        ),
                      ],
                    ),
                  ],
                  
                  if (_todayAttendance!.isCheckedOut) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(),
                    ),
                    if (_todayAttendance!.overtimeStart == null && DateTime.now().hour >= 17)
                      _buildStartOvertimeButton()
                    else if (_todayAttendance!.isOvertimeActive) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overtime Started:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                          Text(
                            DateFormat('hh:mm a').format(_todayAttendance!.overtimeStart!),
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _endOvertime,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('End Overtime'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.red[500],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ]
                    else if (_todayAttendance!.hasOvertime) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overtime Hours:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                          Text(
                            '${_todayAttendance!.overtimeHours.toStringAsFixed(1)} hrs',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the "Attendance Summary" card which shows stats like present days,
  /// absent days, working hours, and overtime for the selected period.
  /// The user can switch between Daily, Weekly, Monthly, and Yearly views.
  Widget _buildSummarySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    offset: const Offset(0, 40),
                    constraints: const BoxConstraints(
                      minWidth: 120,
                      maxWidth: 120,
                    ),
                    elevation: 4,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    onSelected: (value) {
                      setState(() => _selectedPeriod = value);
                      _loadSummary();
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      _buildPopupMenuItem('daily', 'Daily', _selectedPeriod == 'daily', isDark),
                      _buildPopupMenuItem('weekly', 'Weekly', _selectedPeriod == 'weekly', isDark),
                      _buildPopupMenuItem('monthly', 'Monthly', _selectedPeriod == 'monthly', isDark),
                      _buildPopupMenuItem('yearly', 'Yearly', _selectedPeriod == 'yearly', isDark),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedPeriod.substring(0, 1).toUpperCase() + _selectedPeriod.substring(1),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_isLoadingSummary)
              const Center(child: CircularProgressIndicator())
            else if (_summary != null)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Present',
                          _summary!.presentDays.toString(),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          'Half Day',
                          _summary!.halfDays.toString(),
                          Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Absent',
                          _summary!.absentDays.toString(),
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          'Attendance %',
                          '${_summary!.attendancePercentage.toStringAsFixed(1)}%',
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Working Hours',
                          '${_summary!.totalWorkingHours.toStringAsFixed(1)}h',
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          'Overtime',
                          '${_summary!.totalOvertimeHours.toStringAsFixed(1)}h',
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text('No data available', style: TextStyle(color: Colors.grey)),
              )),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String title,
    bool isSelected,
    bool isDark,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent.withOpacity(0.08) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected 
                    ? AppColors.accent 
                    : (isDark ? Colors.white : const Color(0xFF111827)),
                fontSize: 13,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: AppColors.accent, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : color.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  /// Returns the background colour for the attendance status chip
  /// (green = present, orange = half day, red = absent).
  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'half_day':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Builds the animated countdown timer widget that shows how much time
  /// is left until 5 PM.
  /// The colour changes from blue → orange (< 1 hour left) → red (past 5 PM).
  Widget _buildAnimatedCountdown() {
    final now = DateTime.now();
    final isAfter5PM = now.isAfter(_countdownEnd ?? now);
    final isNearEnd = _countdownEnd != null && _remainingTime.inHours < 1;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAfter5PM
                    ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)] // deep blue
                    : (isNearEnd
                        ? [const Color(0xFF0EA5E9), const Color(0xFF0284C7)] // blue
                        : [const Color(0xFF38BDF8), const Color(0xFF0EA5E9)]), // light blue/sky blue
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isAfter5PM
                          ? const Color(0xFF1E3A8A)
                          : const Color(0xFF0EA5E9))
                      .withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (!isAfter5PM)
                  _PulsingContainer(
                    color: const Color(0xFF0EA5E9),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RotatingIcon(
                        icon: Icons.timer_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, scaleValue, child) {
                          return Transform.scale(
                            scale: 0.85 + (0.15 * scaleValue),
                            child: Text(
                              isAfter5PM
                                  ? '00:00:00'
                                  : _formatDuration(_remainingTime),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAfter5PM ? 'Time Over' : 'Until 5 PM',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the green "Mark Attendance" button shown when the field officer
  /// has not yet checked in today. Shows a spinner while the API call is in progress.
  Widget _buildAttendanceButton() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0EA5E9),
            Color(0xFF0284C7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isMarkingAttendance ? null : _markAttendance,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _isMarkingAttendance
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Marking...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Mark\nAttendance',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Builds the orange "Leave Early" button shown when the field officer
  /// is checked in but wants to leave before 5 PM.
  Widget _buildLeaveEarlyButton() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[400]!,
            Colors.orange[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _leaveEarly,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Text(
                    'Leave\nEarly',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the red-orange "Check Out" button shown when the field officer
  /// is checked in and it is after 5 PM.
  Widget _buildCheckOutButton() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEF4444),
            Color(0xFFDC2626),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _checkOut,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Text(
                    'Check\nOut',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the animated orange "Start Overtime" button shown after the
  /// field officer has checked out and it is past 5 PM.
  /// Uses a scale entrance animation and a continuous pulsing background effect.
  Widget _buildStartOvertimeButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Container(
            width: double.infinity,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange[400]!,
                  Colors.orange[600]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startOvertime,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.1),
                child: Stack(
                  children: [
                    _PulsingButtonBackground(color: Colors.orange),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Flexible(
                            child: Text(
                              'Start Overtime',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated helper widgets used inside the dashboard.
// These are private (prefixed with _) because they are only needed here.
// ─────────────────────────────────────────────────────────────────────────────

/// A container that slowly pulses brighter and dimmer using a radial gradient.
/// Used as a background effect on the countdown timer and the overtime button.
class _PulsingContainer extends StatefulWidget {
  final Color color;

  const _PulsingContainer({required this.color});

  @override
  State<_PulsingContainer> createState() => _PulsingContainerState();
}

/// A full-size background layer that pulses to give buttons a glowing effect.
/// Used inside the "Start Overtime" button.
class _PulsingButtonBackground extends StatefulWidget {
  final Color color;

  const _PulsingButtonBackground({required this.color});

  @override
  State<_PulsingButtonBackground> createState() => _PulsingButtonBackgroundState();
}

class _PulsingButtonBackgroundState extends State<_PulsingButtonBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(0.3 * (0.5 + 0.5 * _controller.value)),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingContainerState extends State<_PulsingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(0.3 * (0.5 + 0.5 * _controller.value)),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An icon that continuously rotates 360° in a loop.
/// Used as the timer icon inside the countdown widget.
class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _RotatingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

