import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/project_model.dart';
import '../../../../models/valuation_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/pdf_service.dart';
import '../../../../theme/app_colors.dart';
import '../utils/field_officer_ui_helpers.dart';

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

  Future<void> _generatePdfPreview(Valuation valuation) async {
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
                Text('Fetching project details...', style: TextStyle(fontWeight: FontWeight.bold)),
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
        final file = await PdfService.generateValuationReport(
          valuation: valuation,
          project: project,
        );
        await OpenFile.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(projectResult['message'] ?? 'Failed to load project details for PDF generation'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure dialog is dismissed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
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
          onTap: () => _showValuationDetailsSheet(valuation, isDark),
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

                // Estimated Value & Date Row + PDF action
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
                    Row(
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy').format(valuation.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (valuation.finalReportUrl != null || valuation.submittedReportUrl != null)
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                            color: Colors.red[700],
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final url = valuation.finalReportUrl ?? valuation.submittedReportUrl!;
                              try {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not open PDF: $e')),
                                );
                              }
                            },
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, size: 20),
                            color: Colors.red[400],
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _generatePdfPreview(valuation),
                          ),
                      ],
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

  void _showValuationDetailsSheet(Valuation valuation, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Report Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FieldOfficerUiHelpers.getValuationStatusColor(valuation.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        valuation.statusDisplay.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailRow('Project', valuation.projectTitle, isDark),
                _detailRow('Category', valuation.categoryDisplay, isDark),
                _detailRow(
                  'Estimated Value',
                  valuation.estimatedValue != null
                      ? 'LKR ${NumberFormat('#,##0.00').format(valuation.estimatedValue)}'
                      : 'Pending',
                  isDark,
                  textColor: AppColors.accent,
                ),
                _detailRow('Date Created', DateFormat('MMM dd, yyyy HH:mm').format(valuation.createdAt), isDark),
                if (valuation.description != null && valuation.description!.isNotEmpty)
                  _detailRow('Description', valuation.description!, isDark),
                if (valuation.notes != null && valuation.notes!.isNotEmpty)
                  _detailRow('Notes', valuation.notes!, isDark),

                // Category-specific details
                if (valuation.category == 'land') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  Text('Land Specifications', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 8),
                  if (valuation.landArea != null)
                    _detailRow('Land Area (perches)', valuation.landArea.toString(), isDark),
                  if (valuation.landType != null)
                    _detailRow('Land Type', valuation.landType!, isDark),
                  if (valuation.landLocation != null)
                    _detailRow('Location Address', valuation.landLocation!, isDark),
                  if (valuation.landLatitude != null && valuation.landLongitude != null)
                    _detailRow('GPS Coordinates', '${valuation.landLatitude}, ${valuation.landLongitude}', isDark),
                ],

                if (valuation.category == 'building') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  Text('Building Specifications', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 8),
                  if (valuation.buildingArea != null)
                    _detailRow('Building Area (sq. ft.)', valuation.buildingArea.toString(), isDark),
                  if (valuation.buildingType != null)
                    _detailRow('Building Type', valuation.buildingType!, isDark),
                  if (valuation.buildingLocation != null)
                    _detailRow('Location Address', valuation.buildingLocation!, isDark),
                  if (valuation.buildingLatitude != null && valuation.buildingLongitude != null)
                    _detailRow('GPS Coordinates', '${valuation.buildingLatitude}, ${valuation.buildingLongitude}', isDark),
                  if (valuation.numberOfFloors != null)
                    _detailRow('Number of Floors', valuation.numberOfFloors.toString(), isDark),
                  if (valuation.yearBuilt != null)
                    _detailRow('Year Built', valuation.yearBuilt.toString(), isDark),
                ],

                if (valuation.category == 'vehicle') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  Text('Vehicle Specifications', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 8),
                  if (valuation.vehicleMake != null)
                    _detailRow('Make', valuation.vehicleMake!, isDark),
                  if (valuation.vehicleModel != null)
                    _detailRow('Model', valuation.vehicleModel!, isDark),
                  if (valuation.vehicleYear != null)
                    _detailRow('Year of Manufacture', valuation.vehicleYear.toString(), isDark),
                  if (valuation.vehicleRegistrationNumber != null)
                    _detailRow('Registration No.', valuation.vehicleRegistrationNumber!, isDark),
                  if (valuation.vehicleMileage != null)
                    _detailRow('Mileage (km)', valuation.vehicleMileage.toString(), isDark),
                  if (valuation.vehicleCondition != null)
                    _detailRow('Overall Condition', valuation.vehicleCondition!, isDark),
                ],

                if (valuation.rejectionReason != null && valuation.rejectionReason!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          valuation.rejectionReason!,
                          style: TextStyle(color: isDark ? Colors.white.withOpacity(0.9) : Colors.red[900], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, bool isDark, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }
}
