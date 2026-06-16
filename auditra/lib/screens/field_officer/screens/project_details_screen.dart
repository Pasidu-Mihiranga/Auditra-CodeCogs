import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
import '../../../../services/api_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/shared_dashboard_widgets.dart';
import '../../visit_scheduling_screen.dart';
import '../../project_standups_screen.dart';
import '../utils/field_officer_document_manager.dart';
import '../styles/field_officer_styles.dart';
import 'valuation_reports_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({
    super.key,
    required this.project,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late FieldOfficerDocumentManager _documentManager;
  String? _nextVisitOverride; // Locally updated after scheduling/cancelling

  @override
  void initState() {
    super.initState();
    _documentManager = FieldOfficerDocumentManager(
      context: context,
      setState: setState,
    );
    // Fetch the latest visit date immediately upon loading the screen
    _refreshNextVisit();
  }

  /// After scheduling or cancelling, re-fetch visits and update the next visit display.
  Future<void> _refreshNextVisit() async {
    try {
      final res = await ApiService.getProjectVisits(widget.project.id);
      if (res['success'] == true && mounted) {
        final raw = res['data'];
        final data = raw is List ? raw : <dynamic>[];
        final visits = List<Map<String, dynamic>>.from(data);
        // Find the earliest future scheduled (non-cancelled) visit
        String? nextDate;
        for (final v in visits) {
          final status = (v['status'] ?? '').toString().toLowerCase();
          if (status == 'cancelled' || status == 'completed') continue;
          final dateStr = (v['scheduled_date'] ?? '').toString();
          if (dateStr.isEmpty) continue;
          if (nextDate == null || dateStr.compareTo(nextDate) < 0) {
            nextDate = dateStr;
          }
        }
        setState(() {
          _nextVisitOverride = nextDate ?? '';
        });
      }
    } catch (_) {}
  }

  String _formatPriorityLabel(String priority) {
    if (priority.isEmpty) return 'MEDIUM';
    return priority.toUpperCase();
  }

  Widget _buildSwatchDetailCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : FieldOfficerStyles.lightBlue.withOpacity(0.08);
    final borderColor = isDark ? const Color(0xFF334155) : FieldOfficerStyles.lightBlue.withOpacity(0.25);
    final accentColor = isDark ? const Color(0xFF60A5FA) : FieldOfficerStyles.primaryBlue;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final rowBg = isDark ? const Color(0xFF1E293B) : FieldOfficerStyles.lightBlue.withOpacity(0.08);
    final borderColor = isDark ? const Color(0xFF334155) : FieldOfficerStyles.lightBlue.withOpacity(0.25);
    final accentColor = isDark ? const Color(0xFF60A5FA) : FieldOfficerStyles.primaryBlue;
    
    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine status icons
    IconData statusIcon;
    String statusText = project.statusDisplay;

    switch (project.status) {
      case 'pending':
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'in_progress':
        statusIcon = Icons.pending_actions_rounded;
        break;
      case 'completed':
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'cancelled':
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusIcon = Icons.help_outline_rounded;
    }

    final headerHeight = 300.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Header background with brand blue variants gradient and abstract shapes
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isDark ? const Color(0xFF0F172A) : FieldOfficerStyles.primaryBlue,
                    isDark ? const Color(0xFF151D30) : FieldOfficerStyles.lightBlue,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Abstract decorative shapes
                  Positioned(
                    top: -50,
                    right: -50,
                    child: CircleAvatar(
                      radius: 120,
                      backgroundColor: Colors.white.withOpacity(0.04),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -20,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white.withOpacity(0.03),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          statusText.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Floating top interactive back button (Moved below Positioned.fill to overlap scrollable content)

          // 3. Scrollable content
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Spacer to push sheet down, exposing the header background
                  SizedBox(height: headerHeight - 32),

                  // Content sheet containing the details
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bottom sheet container
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0F19) : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 48, bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              project.title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Inline Metadata
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'ID: ${project.id}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF60A5FA) : FieldOfficerStyles.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  ${project.statusDisplay}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                // Priority Capsule
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    (project.priority ?? 'medium').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFF90CDF4) : FieldOfficerStyles.primaryBlue,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Divider(
                                height: 1, 
                                thickness: 1, 
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
                              ),
                            ),
                            
                            // Key Swatch Cards
                            Text(
                              'Key Information',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.grey[300] : const Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSwatchDetailCard(
                                    title: 'COORDINATOR',
                                    value: project.coordinatorName ?? project.coordinatorUsername,
                                    icon: Icons.person_outline_rounded,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSwatchDetailCard(
                                    title: 'NEXT VISIT',
                                    value: _formatNextVisitLine(
                                      _nextVisitOverride ?? project.nextScheduledVisit,
                                    ),
                                    icon: Icons.calendar_today_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Description
                            if (project.description != null && project.description!.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                project.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
                                  height: 1.6,
                                ),
                              ),
                            ],
                            
                            // Actions List
                            const SizedBox(height: 28),
                            Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.grey[300] : const Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionRow(
                              onTap: () async {
                                await Navigator.of(context).push<bool>(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => VisitSchedulingScreen(
                                      projectId: project.id,
                                      projectTitle: project.title,
                                      appBarTitle: 'Valuation schedule – ${project.title}',
                                      fabLabel: 'Set valuation date',
                                      emptyStateText: 'No valuation date scheduled. Tap the button to choose when you will visit the site.',
                                      confirmDialogTitle: 'Confirm valuation date',
                                      confirmDialogScheduleLabel: 'Set date',
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  _refreshNextVisit();
                                }
                              },
                              icon: Icons.calendar_today_rounded,
                              title: 'Schedule Valuation Visit',
                              subtitle: 'Set date and details for your site visit',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),
                            _buildActionRow(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProjectStandupsScreen(
                                      projectId: project.id,
                                      projectTitle: project.title,
                                    ),
                                  ),
                                );
                              },
                              icon: Icons.forum_rounded,
                              title: 'Daily Standups',
                              subtitle: 'Submit status updates or view history',
                              isDark: isDark,
                            ),
                            
                            // Documents Section
                            if (project.documents.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Text(
                                    'Documents',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.grey[300] : const Color(0xFF0F172A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? FieldOfficerStyles.primaryBlue.withOpacity(0.3) : FieldOfficerStyles.lightBlue.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${project.documents.length}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF60A5FA) : FieldOfficerStyles.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: project.documents.map((doc) {
                                    final isLast = doc == project.documents.last;
                                    return Column(
                                      children: [
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                          leading: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : FieldOfficerStyles.lightBlue.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.insert_drive_file_outlined, color: FieldOfficerStyles.primaryBlue),
                                          ),
                                          title: Text(
                                            doc.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          subtitle: Text(
                                            doc.fileSizeFormatted,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          trailing: doc.fileUrl != null
                                              ? FutureBuilder<bool>(
                                                  key: ValueKey('doc_${doc.id}_${_documentManager.downloadedDocuments.contains(doc.id)}'),
                                                  future: _documentManager.isDocumentDownloaded(doc.id),
                                                  builder: (context, snapshot) {
                                                    final isDownloaded = snapshot.data ?? false;
                                                    return Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(50),
                                                        onTap: () async {
                                                          if (isDownloaded) {
                                                            final filePath = await _documentManager.getLocalFilePath(doc.id);
                                                            if (filePath != null) {
                                                              await _documentManager.viewDownloadedDocument(filePath);
                                                            }
                                                          } else {
                                                            await _documentManager.downloadDocument(doc);
                                                          }
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: Icon(
                                                            isDownloaded ? Icons.visibility_rounded : Icons.download_rounded,
                                                            size: 18,
                                                            color: FieldOfficerStyles.primaryBlue,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : null,
                                        ),
                                        if (!isLast)
                                          Divider(height: 1, indent: 70, color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Overlapping Floating Capsule Button ("Add To Card" style)
                      Positioned(
                        top: -24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ValuationReportsScreen(
                                      project: project,
                                      onProjectUpdated: () {
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                              label: const Text(
                                'VALUATION REPORTS', 
                                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 13)
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FieldOfficerStyles.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 8,
                                shadowColor: FieldOfficerStyles.primaryBlue.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Floating top interactive back button (Moved here to overlay and receive touch events)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNextVisitLine(String? iso) {
    if (iso == null || iso.isEmpty) return 'Not set';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
