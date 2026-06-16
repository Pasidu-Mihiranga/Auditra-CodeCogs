import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/offline_db_service.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';

/// Screen for viewing and scheduling site visits for a given project.
/// Supports offline caching — visits are shown from local cache when offline
/// and refreshed from the API when a connection is available.
class VisitSchedulingScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;
  final String? appBarTitle;
  final String? fabLabel;
  final String? emptyStateText;
  final String? confirmDialogTitle;
  final String? confirmDialogScheduleLabel;

  const VisitSchedulingScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.appBarTitle,
    this.fabLabel,
    this.emptyStateText,
    this.confirmDialogTitle,
    this.confirmDialogScheduleLabel,
  });

  @override
  State<VisitSchedulingScreen> createState() => _VisitSchedulingScreenState();
}

class _VisitSchedulingScreenState extends State<VisitSchedulingScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  String? _error;
  bool _dataChanged = false; // Track if scheduling/cancelling happened
  final ScrollController _scrollController = ScrollController();
  final Set<int> _expandedVisitIds = {};

  @override
  void initState() {
    super.initState();
    _loadCachedVisitsOnStartup();
    _loadVisits();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedVisitsOnStartup() async {
    try {
      await OfflineDBService.initOfflineDB();
      final cached = OfflineStorageService.getCachedProjectVisits(widget.projectId);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() { _visits = cached; _loading = false; });
      }
    } catch (_) {}
  }

  Future<void> _loadVisits() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getProjectVisits(widget.projectId);
      if (res['success'] == true) {
        final raw = res['data'];
        final data = raw is List ? raw : <dynamic>[];
        final normalized = List<Map<String, dynamic>>.from(data);
        OfflineStorageService.cacheProjectVisits(widget.projectId, normalized);
        setState(() { _visits = normalized; _loading = false; });
      } else {
        final cached = OfflineStorageService.getCachedProjectVisits(widget.projectId);
        if (cached != null && cached.isNotEmpty) {
          setState(() { _visits = cached; _loading = false; _error = null; });
        } else {
          setState(() {
            _error = (res['message'] ?? 'Failed to load valuation dates').toString();
            _loading = false;
          });
        }
      }
    } catch (e) {
      final cached = OfflineStorageService.getCachedProjectVisits(widget.projectId);
      if (cached != null && cached.isNotEmpty) {
        setState(() { _visits = cached; _loading = false; _error = null; });
      } else {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  bool _isOfflineMessage(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return m.contains('you are offline') ||
        m.contains('network is unreachable') ||
        m.contains('connection failed') ||
        m.contains('failed host lookup');
  }

  String _formatVisitDate(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      return DateFormat('EEE, MMM d, y').format(parsed);
    } catch (_) {
      return rawDate;
    }
  }

  String _formatStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return 'Scheduled';
    return normalized
        .split('_')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  // ─────────── Schedule Visit (Bottom Sheet) ───────────

  Future<void> _scheduleVisit() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF00A3FF),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    final notesCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2332) : Colors.white;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Header with gradient
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A3FF), Color(0xFF0082FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A3FF).withOpacity(0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.confirmDialogTitle ?? 'Confirm valuation date',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMMM d, y').format(picked),
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Notes field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    hintText: 'Add any details about this visit...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE0E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE0E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF00A3FF), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A3FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          widget.confirmDialogScheduleLabel ?? 'Set date',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await ApiService.scheduleProjectVisit(
        projectId: widget.projectId,
        scheduledDate: picked,
        notes: notesCtrl.text.trim(),
      );
      if (res['success'] == true && mounted) {
        _dataChanged = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Visit scheduled. Client will be notified.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadVisits();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((res['message'] ?? 'Failed to schedule visit').toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─────────── Cancel Visit (Bottom Sheet) ───────────

  Future<void> _cancelVisit(Map<String, dynamic> visit) async {
    final visitId = visit['id'];
    if (visitId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2332) : Colors.white;
    final reasonCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Red header
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade500, Colors.red.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.event_busy_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cancel this visit?',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatVisitDate((visit['scheduled_date'] ?? '').toString()),
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Warning
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.orange.withOpacity(0.1) : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.orange.shade600, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The client will be notified about this cancellation with your reason.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark ? Colors.orange[200] : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Reason field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: reasonCtrl,
                        maxLines: 3,
                        minLines: 2,
                        onChanged: (_) => setSheetState(() {}),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Reason for cancellation *',
                          labelStyle: TextStyle(color: Colors.red.shade400),
                          hintText: 'Explain why this visit is being cancelled...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFFF5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.red.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                'Go back',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: reasonCtrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel Visit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await ApiService.cancelProjectVisit(
        projectId: widget.projectId,
        visitId: visitId,
        reason: reasonCtrl.text.trim(),
      );
      if (res['success'] == true && mounted) {
        _dataChanged = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Visit cancelled. Client has been notified.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadVisits();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((res['message'] ?? 'Failed to cancel visit').toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─────────── Visit Card ───────────

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return const Color(0xFF00A3FF);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.event_available_rounded;
    }
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateRaw = (visit['scheduled_date'] ?? '').toString();
    final notes = (visit['notes'] ?? visit['note'] ?? '').toString().trim();
    final statusRaw = (visit['status'] ?? 'scheduled').toString();
    final status = _formatStatus(statusRaw);
    final isCancelled = statusRaw.trim().toLowerCase() == 'cancelled';
    final isCompleted = statusRaw.trim().toLowerCase() == 'completed';
    final isScheduled = !isCancelled && !isCompleted;
    final cancellationReason = (visit['cancellation_reason'] ?? '').toString().trim();
    final color = _statusColor(statusRaw);
    final visitId = visit['id'] as int?;
    final isExpanded = visitId != null && _expandedVisitIds.contains(visitId);

    return GestureDetector(
      onTap: () {
        if (visitId != null && isScheduled) {
          setState(() {
            if (isExpanded) {
              _expandedVisitIds.remove(visitId);
            } else {
              _expandedVisitIds.add(visitId);
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCancelled
              ? Colors.red.withOpacity(isDark ? 0.3 : 0.15)
              : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE6EEF8)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCancelled
                ? Colors.red.withOpacity(0.06)
                : Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_statusIcon(statusRaw), color: color, size: 24),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatVisitDate(dateRaw),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1C1E21),
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.red.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (notes.isNotEmpty)
                        Text(
                          notes,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? Colors.grey[400] : const Color(0xFF4F5B67),
                          ),
                        )
                      else
                        Text(
                          'No notes added',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[600] : const Color(0xFF90A4AE),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cancellation reason
          if (isCancelled && cancellationReason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.08) : const Color(0xFFFFF5F5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.red.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cancellationReason,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.red[200] : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Cancel button for scheduled visits
          if (isScheduled)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              child: isExpanded
                  ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF0F4F8),
                          ),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _cancelVisit(visit),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded, size: 16, color: Colors.red.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Text(
                                  'Cancel this visit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
        ],
      ),
    ),
    );
  }

  // ─────────── Dynamic Island Header ───────────

  Widget _buildDynamicIsland(BuildContext context) {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        double offset = 0;
        if (_scrollController.hasClients) {
          offset = _scrollController.offset.clamp(0.0, 100.0);
        }
        final factor = offset / 100.0;
        final marginH = 16.0 + (16.0 * factor);
        final topPadding = MediaQuery.of(context).padding.top;
        final outerTopMargin = topPadding + 12.0;

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.only(
              top: outerTopMargin,
              left: marginH,
              right: marginH,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  height: kToolbarHeight + 8.0 - (8.0 * factor),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00A3FF).withOpacity(0.55),
                        const Color(0xFF0082FF).withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2 + (0.1 * factor)),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -30,
                        right: -20,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      Positioned(
                        bottom: -20,
                        left: 30,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(_dataChanged),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.appBarTitle ?? 'Valuation Schedule',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  widget.projectTitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────── Build ───────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_dataChanged);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Main content area
            SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.orange.withOpacity(0.15) : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _isOfflineMessage(_error) ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                                    color: _isOfflineMessage(_error) ? Colors.orange : AppColors.error,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _isOfflineMessage(_error)
                                      ? 'You are offline. Saved valuation dates will appear once internet is back.'
                                      : _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isOfflineMessage(_error)
                                        ? (isDark ? Colors.orange[200] : const Color(0xFF8D6E63))
                                        : AppColors.error,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _visits.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.accent.withOpacity(0.15) : const Color(0xFFEAF3FF),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        Icons.calendar_month_rounded,
                                        color: isDark ? AppColors.accent : AppColors.primary,
                                        size: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      widget.emptyStateText ?? 'No visits scheduled',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF546E7A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadVisits,
                              color: const Color(0xFF00A3FF),
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 40, 16, 120),
                                itemCount: _visits.length,
                                itemBuilder: (ctx, i) => _buildVisitCard(_visits[i]),
                              ),
                            ),
            ),
            // Floating bottom button with gradient fade
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 1.0],
                    colors: [
                      bgColor.withOpacity(0.0),
                      bgColor.withOpacity(0.8),
                      bgColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _scheduleVisit,
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00A3FF), Color(0xFF0082FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00A3FF).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                widget.fabLabel ?? 'Set valuation date',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Dynamic island header
            _buildDynamicIsland(context),
          ],
        ),
      ),
    );
  }
}
