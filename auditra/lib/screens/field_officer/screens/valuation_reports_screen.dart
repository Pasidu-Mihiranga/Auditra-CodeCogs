import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
import '../../../../models/valuation_model.dart';
import '../../../../services/api_service.dart';
import '../../valuation_form_screen.dart';
import '../../../../services/pdf_service.dart';
import '../utils/field_officer_document_manager.dart';
import '../utils/field_officer_ui_helpers.dart';
import '../../../../theme/app_colors.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen that lists all valuation reports for a given project
/// Field officers can view, create, edit, submit, and delete reports here
class ValuationReportsScreen extends StatefulWidget {
  final Project project;
  final VoidCallback? onProjectUpdated; // Optional callback to notify parent when project data changes

  const ValuationReportsScreen({
    super.key,
    required this.project,
    this.onProjectUpdated,
  });

  @override
  State<ValuationReportsScreen> createState() => _ValuationReportsScreenState();
}

/// Holds all the mutable state and logic for [ValuationReportsScreen].
/// This is the "brain" behind the screen — it loads data, handles user actions,
/// and tells Flutter when to redraw the UI.
class _ValuationReportsScreenState extends State<ValuationReportsScreen> {
  late FieldOfficerDocumentManager _documentManager; // Handles document-related operations
  Project? _currentProject; // Holds the latest project data after refreshes
  bool _isLoading = false; // Controls loading indicator visibility

  /// Called once when the screen first opens.
  /// Stores the project passed from the parent and sets up the document manager
  /// that is used for PDF generation and file operations.
  @override
  void initState() {
    super.initState();
    // Initialize with the project passed from the parent widget
    _currentProject = widget.project;
    _documentManager = FieldOfficerDocumentManager(
      context: context,
      setState: setState,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Fetches the latest project data from the API and updates the UI
  /// Also notifies the parent widget via [onProjectUpdated] callback
  Future<void> _refreshProject() async {
    setState(() => _isLoading = true); // Show spinner while loading
    try {
      final result = await ApiService.getProject(widget.project.id); // Call the backend
      if (result['success']) {
        setState(() {
          // Replace old project data with the fresh copy from the server
          _currentProject = Project.fromJson(result['data']);
        });
        // Tell the parent screen (e.g. dashboard) to also refresh its project list
        widget.onProjectUpdated?.call();
      }
    } catch (e) {
      print('Error refreshing project: $e'); // Log silently; don't crash the screen
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Hide spinner regardless of success or failure
      }
    }
  }

  /// Shows a confirmation dialog, then deletes the given [valuation] via the API.
  /// On success, refreshes the project list. On failure, shows an error snackbar.
  Future<void> _deleteValuation(Valuation valuation) async {
    // Ask the user to confirm before permanently deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete this ${valuation.categoryDisplay} report? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // User chose Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // User chose Delete
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return; // User cancelled — do nothing

    setState(() => _isLoading = true); // Show spinner while the API call runs

    try {
      final result = await ApiService.deleteValuation(valuation.id); // Send delete request

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshProject(); // Reload list after deletion
        }
      } else {
        // Server returned an error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Unexpected network/parse error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Always hide spinner when done
      }
    }
  }

  Widget _buildHeader(BuildContext context, Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1220) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Valuation Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  project.title,
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Refresh button
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF3B82F6),
              ),
              onPressed: _refreshProject,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the entire screen layout
  ///
  /// The screen uses a custom static header and a scrollable list
  /// of valuation report cards.
  ///
  /// Shows a loading spinner while data is being fetched,
  /// and an empty-state message if no reports exist yet
  @override
  Widget build(BuildContext context) {
    // Use refreshed project data if available, otherwise fall back to the initial data
    final project = _currentProject ?? widget.project;
    final valuations = project.valuations;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Static Header
          _buildHeader(context, project),
          
          // Main scrollable content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : valuations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F9FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.assignment_outlined,
                                size: 48,
                                color: isDark ? Colors.grey[400] : const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No reports yet',
                              style: TextStyle(
                                fontSize: 20,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to create one',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    // List of valuation report cards
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 16,
                          right: 16,
                          bottom: 100, // Space for FAB
                        ),
                        itemCount: valuations.length,
                        itemBuilder: (context, index) {
                          final valuation = valuations[index];
                          return _buildReportCard(valuation, project);
                        },
                      ),
          ),
        ],
      ),
      // FloatingActionButton only shown when the project is actively in progress
      // (a completed or pending project should not allow new reports)
      floatingActionButton: project.status == 'in_progress'
          ? Container(
              margin: const EdgeInsets.only(bottom: 16, right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () async {
                  // Navigate to the valuation form to create a new report
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ValuationFormScreen(project: project),
                    ),
                  );
                  // Refresh the list if a new report was successfully created
                  if (result == true) {
                    _refreshProject();
                  }
                },
                backgroundColor: const Color(0xFF4CA0FF),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text(
                  'New Report', 
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  )
                ),
              ),
            )
          : null,
    );
  }

  /// Builds a card widget for a single [valuation] report.
  ///
  /// Each card has three sections:
  ///   1. **Header** - category icon, name, and a colour-coded status badge
  ///      (DRAFT / SUBMITTED / APPROVED / REJECTED).
  ///   2. **Rejection banner** - a red strip shown only when the report was rejected,
  ///      displaying the accessor's rejection reason.
  ///   3. **Body** - estimated value, creation date, short description preview,
  ///      and a row of action icon buttons:
  ///        - PDF icon   - opens the server PDF or generates a local preview.
  ///        - Edit icon  - opens the valuation form for editing (editable reports only).
  ///        - Submit icon - opens the form to review and submit (draft/rejected only).
  ///        - Delete icon - asks for confirmation then deletes (deletable reports only).
  Widget _buildReportCard(Valuation valuation, Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = FieldOfficerUiHelpers.getValuationStatusColor(valuation.status);
    final isDraft = valuation.status == 'draft';
    final isRejected = valuation.status == 'rejected';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRejected 
              ? Colors.red.shade300 
              : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE6EEF8)),
          width: isRejected ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card header: shows category icon, name, and status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDark ? 0.2 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(valuation.category),
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    valuation.categoryDisplay,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: isDark ? Colors.white : const Color(0xFF1C1E21),
                    ),
                  ),
                ),
                // Status badge pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    valuation.statusDisplay.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Rejection reason banner
          if (isRejected && valuation.rejectionReason != null && valuation.rejectionReason!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.red.withOpacity(isDark ? 0.3 : 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reason: ${valuation.rejectionReason}',
                      style: TextStyle(
                        color: isDark ? Colors.red.shade300 : Colors.red.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row showing estimated value and creation date side by side
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Value',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'LKR ${NumberFormat('#,##0.00').format(valuation.estimatedValue ?? 0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF1C1E21),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMM dd, yyyy').format(valuation.createdAt),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Optional description preview (truncated to 2 lines)
                if (valuation.description != null && valuation.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    valuation.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 16),
                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // PDF Button
                    if (valuation.finalReportUrl != null || valuation.submittedReportUrl != null)
                      _buildActionButton(
                        icon: Icons.picture_as_pdf_rounded,
                        color: Colors.red,
                        tooltip: 'View PDF Report',
                        onPressed: () async {
                          final url = valuation.finalReportUrl ?? valuation.submittedReportUrl!;
                          try {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open PDF: $e')),
                              );
                            }
                          }
                        },
                      )
                    else 
                      _buildActionButton(
                        icon: Icons.picture_as_pdf_rounded,
                        color: Colors.red,
                        tooltip: 'Generate PDF Preview',
                        onPressed: () async {
                          try {
                            final file = await PdfService.generateValuationReport(
                              valuation: valuation,
                              project: project,
                            );
                            await OpenFile.open(file.path);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error generating PDF: $e')),
                              );
                            }
                          }
                        },
                      ),
                    
                    const SizedBox(width: 12),

                    // Edit button
                    if (FieldOfficerUiHelpers.canEditValuation(valuation)) ...[
                      _buildActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF00A3FF),
                        tooltip: 'Edit Report',
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ValuationFormScreen(
                                project: project,
                                existingValuation: valuation,
                              ),
                            ),
                          );
                          if (result == true) {
                            _refreshProject();
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                    ],
                      
                    // Submit button
                    if (isDraft || isRejected) ...[
                       _buildActionButton(
                        icon: Icons.send_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Submit Report',
                        onPressed: () async {
                           final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ValuationFormScreen(
                                project: project,
                                existingValuation: valuation,
                              ),
                            ),
                          );
                          if (result == true) {
                            _refreshProject();
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Delete button
                    if (FieldOfficerUiHelpers.canDeleteValuation(valuation))
                      _buildActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete Report',
                        onPressed: () => _deleteValuation(valuation),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the icon that best represents a valuation [category].
  ///
  /// - "land"     -> mountain/landscape icon
  /// - "building" -> city building icon
  /// - "vehicle"  -> car icon
  /// - anything else -> generic category icon
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'land':
        return Icons.landscape;
      case 'building':
        return Icons.location_city;
      case 'vehicle':
        return Icons.directions_car;
      default:
        return Icons.category;
    }
  }
}
