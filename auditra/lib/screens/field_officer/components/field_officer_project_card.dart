import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
import '../../../../theme/app_colors.dart';

class FieldOfficerProjectCard extends StatefulWidget {
  final Project project;
  final Function(Project) onViewDetails;
  final Function(Project) onViewReports;
  final Function(Project) onCreateReport;
  final Function(Project) onSubmit;
  final void Function(Project)? onScheduleVisit;

  const FieldOfficerProjectCard({
    super.key,
    required this.project,
    required this.onViewDetails,
    required this.onViewReports,
    required this.onCreateReport,
    required this.onSubmit,
    this.onScheduleVisit,
  });

  @override
  State<FieldOfficerProjectCard> createState() => _FieldOfficerProjectCardState();
}

class _FieldOfficerProjectCardState extends State<FieldOfficerProjectCard> {
  bool _isExpanded = false;

  static String _formatNextVisitLine(String? iso) {
    if (iso == null || iso.isEmpty) return 'Not set';
    try {
      return DateFormat('MMM d').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = widget.project.priority ?? 'medium';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Status colors
    Color statusColor;
    Color statusBg;
    switch (widget.project.status) {
      case 'pending':
        statusColor = const Color(0xFFD97706); // Amber
        statusBg = isDark ? const Color(0xFF3A2D1B) : const Color(0xFFFEF3C7);
        break;
      case 'in_progress':
        statusColor = AppColors.accent; // Vibrant Blue
        statusBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0F2FE);
        break;
      case 'completed':
        statusColor = const Color(0xFF059669); // Emerald Green
        statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
        break;
      case 'cancelled':
        statusColor = const Color(0xFFE11D48); // Rose Red
        statusBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFE4E6);
        break;
      default:
        statusColor = const Color(0xFF4B5563);
        statusBg = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    }

    // Priority colors
    Color priorityColor;
    Color priorityBg;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = const Color(0xFFDC2626); // Rose/Red
        priorityBg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        break;
      case 'low':
        priorityColor = const Color(0xFF2563EB); // Royal Blue
        priorityBg = isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE);
        break;
      case 'medium':
      default:
        priorityColor = const Color(0xFFD97706); // Amber
        priorityBg = isDark ? const Color(0xFF3A2D1B) : const Color(0xFFFEF3C7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status line highlight at the top (Image 3 card red/color line)
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.project.statusDisplay.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Priority chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: priorityColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Details arrow navigation button
                      GestureDetector(
                        onTap: () => widget.onViewDetails(widget.project),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Title
                  Text(
                    widget.project.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  
                  // Description (Only show a snippet if exists)
                  if (widget.project.description != null && widget.project.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.project.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Coordinator & Next Scheduled Visit sub-container (dashboard card styling)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.project.coordinatorName ?? widget.project.coordinatorUsername,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatNextVisitLine(widget.project.nextScheduledVisit),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Collapsible Buttons Panel
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _isExpanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              if (widget.project.status == 'in_progress') ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildSimpleButton(
                                    context: context,
                                    label: 'Create Report',
                                    onTap: () => widget.onCreateReport(widget.project),
                                    isPrimary: false,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              // Submit to Accessor button
                              SizedBox(
                                width: double.infinity,
                                child: _buildSimpleButton(
                                  context: context,
                                  label: 'Submit to Accessor',
                                  onTap: () => widget.onSubmit(widget.project),
                                  isPrimary: true,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    required bool isDark,
  }) {
    if (isPrimary) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      );
    }
  }
}
