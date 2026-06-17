import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/project_model.dart';
import '../../../../models/valuation_model.dart';
import '../../../../services/api_service.dart';
import '../../../../theme/app_colors.dart';
import '../utils/field_officer_ui_helpers.dart';
import 'valuation_reports_screen.dart';

class ValuationHistoryScreen extends StatefulWidget {
  const ValuationHistoryScreen({super.key});

  @override
  State<ValuationHistoryScreen> createState() => _ValuationHistoryScreenState();
}

class _ValuationHistoryScreenState extends State<ValuationHistoryScreen> {
  List<Valuation> _valuations = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadValuations();
  }

  Future<void> _loadValuations() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final result = await ApiService.getValuations();

    if (!mounted) return;

    if (result['success'] == true) {
      try {
        final dynamic data = result['data'];
        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map && data.containsKey('results') && data['results'] is List) {
          rawList = data['results'];
        }

        setState(() {
          _valuations = rawList.map((v) => Valuation.fromJson(v)).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Error parsing reports: $e';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _error = result['message'] ?? 'Failed to load valuation reports';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToReportsScreen(Valuation valuation) async {
    // Show loading indicator dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          margin: EdgeInsets.all(24),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Loading project reports...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final projectResult = await ApiService.getProject(valuation.projectId);
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog

      if (projectResult['success'] == true) {
        final project = Project.fromJson(projectResult['data']);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ValuationReportsScreen(
              project: project,
              targetValuationId: valuation.id.toString(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(projectResult['message'] ?? 'Failed to load project details'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure dialog is dismissed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter valuations based on search query and status filter
    final filteredValuations = _valuations.where((v) {
      final matchesSearch = v.projectTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.categoryDisplay.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatusFilter == 'all' || v.status == _selectedStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Valuation History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: _loadValuations,
            tooltip: 'Refresh list',
          ),
        ],
      ),
      body: Column(
        children: [
          // Premium Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                        hintText: 'Search history by project or details...',
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

          // Horizontal scrollable filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'All', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('draft', 'Drafts', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('submitted', 'Submitted', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('approved', 'Approved', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('rejected', 'Rejected', isDark),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error.withOpacity(0.8)),
                            const SizedBox(height: 16),
                            Text(_error, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadValuations,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : filteredValuations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                                      ? 'No matching reports found'
                                      : 'No valuation reports yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredValuations.length,
                            itemBuilder: (context, index) {
                              final valuation = filteredValuations[index];
                              return _buildValuationCard(valuation, isDark);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterVal, String label, bool isDark) {
    final isSelected = _selectedStatusFilter == filterVal;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = filterVal;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563)),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildValuationCard(Valuation valuation, bool isDark) {
    final statusColor = FieldOfficerUiHelpers.getValuationStatusColor(valuation.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _navigateToReportsScreen(valuation),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Category Icon, Status Badge)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(valuation.category),
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        valuation.categoryDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        valuation.statusDisplay.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Project Title
                Text(
                  valuation.projectTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),

                // Description (if any)
                if (valuation.description != null && valuation.description!.isNotEmpty) ...[
                  Text(
                    valuation.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(height: 1),
                const SizedBox(height: 12),

                // Estimated Value & Date Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Value',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          valuation.estimatedValue != null
                              ? 'LKR ${NumberFormat('#,##0.00').format(valuation.estimatedValue)}'
                              : 'Pending',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(valuation.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'land':
        return Icons.landscape_rounded;
      case 'building':
        return Icons.location_city_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      default:
        return Icons.category_rounded;
    }
  }

}
