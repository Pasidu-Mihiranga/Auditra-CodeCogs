import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../models/payment_slip_model.dart';

class PaymentSlipsScreen extends StatefulWidget {
  final String? role;
  final bool showAppBar;
  final bool showOnlyOwn; // If true, show only user's own payment slips regardless of role
  
  const PaymentSlipsScreen({
    super.key, 
    this.role,
    this.showAppBar = true,
    this.showOnlyOwn = false,
  });

  @override
  State<PaymentSlipsScreen> createState() => _PaymentSlipsScreenState();
}

class _PaymentSlipsScreenState extends State<PaymentSlipsScreen> {
  List<PaymentSlip> _paymentSlips = [];
  List<PaymentSlip> _othersPaymentSlips = [];
  bool _isLoading = true;
  String? _userRole;
  int? _currentUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Roles that should have admin-style structure (left-aligned, black text, simple)
  final List<String> _leftAlignRoles = [
    'admin',
    'hr_head',
  ];
  
  bool get _shouldAlignLeft {
    final role = _userRole ?? widget.role;
    return role != null && _leftAlignRoles.contains(role);
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadPaymentSlips();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserRole() async {
    if (widget.role == null) {
      final roleResult = await ApiService.getMyRole();
      if (roleResult['success'] && mounted) {
        setState(() {
          _userRole = roleResult['data']['role'];
        });
      }
    } else {
      _userRole = widget.role;
    }
    
    // Get current user ID for filtering
    final prefs = await SharedPreferences.getInstance();
    final userIdString = prefs.getString('user_id');
    if (userIdString != null) {
      _currentUserId = int.tryParse(userIdString);
    }
  }

  Future<void> _loadPaymentSlips() async {
    setState(() => _isLoading = true);

    try {
      // Check if user is admin or HR Head - if so, load all payment slips and separate them
      // UNLESS showOnlyOwn is true (for Profile tab)
      final role = _userRole ?? widget.role;
      final isAdminOrHR = (role == 'admin' || role == 'hr_head') && !widget.showOnlyOwn;
      
      if (isAdminOrHR) {
        // Load all payment slips (excluding admin's own)
        final allResult = await ApiService.getAllPaymentSlips();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            
            // Process all payment slips and filter out admin's own
            if (allResult['success']) {
              final allData = allResult['data'];
              List<PaymentSlip> allSlips = [];
              
              if (allData is List) {
                allSlips = allData.map((json) {
                  return PaymentSlip.fromJson(json as Map<String, dynamic>);
                }).toList();
              } else if (allData is Map && allData.containsKey('results')) {
                allSlips = (allData['results'] as List)
                    .map((json) => PaymentSlip.fromJson(json as Map<String, dynamic>))
                    .toList();
              }
              
              // Filter out ALL admin payment slips - admin should not see any admin slips
              // Exclude by role to ensure all admin slips are removed (regardless of userId)
              _othersPaymentSlips = allSlips.where((slip) {
                // Remove any payment slip where role is 'admin'
                return slip.role != 'admin';
              }).toList();
              
              // Set _paymentSlips to empty for admin (they only see others)
              _paymentSlips = [];
            } else {
              _othersPaymentSlips = [];
              _paymentSlips = [];
            }
          });
        }
        return;
      }
      
      // For non-admin users, load only their own payment slips
      final result = await ApiService.getMyPaymentSlips();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success']) {
            final data = result['data'];
            try {
              if (data is List) {
                _paymentSlips = data.map((json) {
                  try {
                    return PaymentSlip.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    print('Error parsing payment slip item: $e');
                    print('Item data: $json');
                    rethrow;
                  }
                }).toList();
              } else if (data is Map && data.containsKey('results')) {
                _paymentSlips = (data['results'] as List)
                    .map((json) {
                      try {
                        return PaymentSlip.fromJson(json as Map<String, dynamic>);
                      } catch (e) {
                        print('Error parsing payment slip item: $e');
                        print('Item data: $json');
                        rethrow;
                      }
                    })
                    .toList();
              } else {
                // Handle case where data might be directly a list
                _paymentSlips = [];
              }
            } catch (e) {
              print('Error processing payment slips data: $e');
              _paymentSlips = [];
              rethrow;
            }
          } else {
            _paymentSlips = [];
            // Silently handle error - don't show error message
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _paymentSlips = [];
        });
        // Silently handle error - don't show error message
      }
    }
  }

  Widget _buildHeader(BuildContext context, bool isAdminOrHR) {
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
                  isAdminOrHR ? 'All Payment Slips' : 'Payment Slips',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Auditra System',
                  style: TextStyle(
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
              onPressed: _loadPaymentSlips,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _userRole ?? widget.role;
    // If showOnlyOwn is true, treat as regular user (not admin/HR) to show only own slips
    final isAdminOrHR = !widget.showOnlyOwn && (role == 'admin' || role == 'hr_head');
    final isHRHead = !widget.showOnlyOwn && (role == 'hr_head');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final body = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (isAdminOrHR 
              ? _othersPaymentSlips.isEmpty 
              : _paymentSlips.isEmpty)
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
                          Icons.receipt_long_rounded,
                          size: 48,
                          color: isDark ? Colors.grey[400] : const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No payment slips found',
                        style: TextStyle(
                          fontSize: 20,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payment slips will appear here once admin uploads them',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPaymentSlips,
                  child: Column(
                    children: [
                      // Create and Upload buttons for HR Head
                      if (isHRHead) _buildHRHeadActionButtons(),
                      // Payment slips list
                      Expanded(
                        child: isAdminOrHR
                            ? _buildAdminView()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: _paymentSlips.length,
                                itemBuilder: (context, index) {
                                  final slip = _paymentSlips[index];
                                  return _buildPaymentSlipCard(slip, isAdminOrHR);
                                },
                              ),
                      ),
                    ],
                  ),
                );
    
    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF9FAFB),
        body: Column(
          children: [
            _buildHeader(context, isAdminOrHR),
            Expanded(child: body),
          ],
        ),
      );
    }
    
    return body;
  }

  /// Build action buttons for HR Head (Create and Upload Payment Slips)
  Widget _buildHRHeadActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.blue[50],
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _createPaymentSlips,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Create Payment Slips'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF10B981) : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _uploadPaymentSlips,
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              label: const Text('Upload Payment Slips'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFF59E0B) : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Create payment slips for all employees
  Future<void> _createPaymentSlips() async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Payment Slips'),
        content: Text(
          'Generate payment slips for all employees for ${_getMonthName(currentMonth)} $currentYear.\n\nExisting payment slips for this month will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final generateResult = await ApiService.generatePaymentSlips(
      month: currentMonth,
      year: currentYear,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (generateResult['success']) {
      final data = generateResult['data'];
      final generated = data['generated_count'] ?? 0;
      final updated = data['updated_count'] ?? 0;
      final total = data['total_count'] ?? 0;
      
      String message;
      if (total > 0) {
        if (generated > 0 && updated > 0) {
          message = 'Payment slips created successfully!\n$generated created, $updated updated\n(Total: $total employees)';
        } else if (updated > 0) {
          message = 'Payment slips updated successfully for $updated employees';
        } else {
          message = 'Payment slips created successfully for $generated employees';
        }
      } else {
        message = data['message'] ?? 'No payment slips generated. All eligible employees may already have payment slips for this month/year.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: total > 0 ? Colors.green : Colors.orange,
          duration: Duration(seconds: total > 0 ? 4 : 5),
        ),
      );
      
      // Refresh the list
      _loadPaymentSlips();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(generateResult['message'] ?? 'Failed to create payment slips'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  /// Upload payment slips for employees to view
  Future<void> _uploadPaymentSlips() async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Payment Slips'),
        content: Text(
          'This will make payment slips visible to all employees for ${_getMonthName(currentMonth)} $currentYear.\n\nEmployees will be able to view their own payment slips after this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final uploadResult = await ApiService.uploadPaymentSlips(
      month: currentMonth,
      year: currentYear,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (uploadResult['success']) {
      final data = uploadResult['data'];
      final uploaded = data['uploaded_count'] ?? 0;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment slips uploaded successfully for $uploaded employees!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Refresh the list
      _loadPaymentSlips();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadResult['message'] ?? 'Failed to upload payment slips'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildAdminView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter payment slips based on search query (only others, not admin's own)
    // Double-check to ensure NO admin payment slips are displayed
    final filteredSlips = _searchQuery.isEmpty
        ? _othersPaymentSlips.where((slip) => slip.role != 'admin').toList()
        : _othersPaymentSlips.where((slip) {
            // Ensure role is not admin AND matches search query
            if (slip.role == 'admin') return false;
            final employeeNumber = slip.employeeNumber ?? slip.userId.toString();
            return employeeNumber.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Search Bar
        Row(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by Employee Number',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: isDark ? Colors.grey[400] : Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        
        // All Payment Slips (excluding admin's own - ensure no admin slips are displayed)
        ...filteredSlips.where((slip) => slip.role != 'admin').map((slip) => _buildPaymentSlipCard(slip, true)),
        
        // No results message
        if (_searchQuery.isNotEmpty && filteredSlips.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No payment slips found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No employee found with number: $_searchQuery',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSlipCard(PaymentSlip slip, bool showEmployeeName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(slip.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE6EEF8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          trailing: const SizedBox.shrink(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored header container matching valuation reports screen card header
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
                        _getStatusIcon(slip.status),
                        size: 20,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${slip.monthDisplay} ${slip.year}',
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
                        slip.statusDisplay.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
              ),
              // Collapsed Body container
              Container(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Net Salary',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(slip.netSalary)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Colors.green,
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
                                'Pay Slip No',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slip.paySlipNumber ?? 'PS-${slip.year}${slip.month.toString().padLeft(2, '0')}-${slip.userId}',
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
                    if (showEmployeeName || (slip.userFullName.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(height: 16),
                      if (showEmployeeName && slip.userFullName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 16, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                'Employee: ${slip.userFullName}',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 16, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            'Employee no: ${slip.employeeNumber ?? slip.userId.toString()}',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.work_outline_rounded, size: 16, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            'Role: ${slip.roleDisplay}',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: _buildPaymentSlipDetails(slip),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSlipDetails(PaymentSlip slip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPaymentSlipHeader(slip),
        const SizedBox(height: 20),
        _buildSalaryBreakdown(slip),
        const SizedBox(height: 24),
        _buildActionButtons(slip),
      ],
    );
  }

  Widget _buildActionButtons(PaymentSlip slip) {
    final role = _userRole ?? widget.role;
    final isAdminOrHR = role == 'admin' || role == 'hr_head';
    final isAdmin = role == 'admin'; // Keep separate for edit/delete permissions
    
    return Column(
      children: [
        // Download PDF button - Available for all users (same as admin dashboard)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _downloadPaymentSlipPDF(slip),
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Download PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (isAdminOrHR) ...[
              // Edit button - Admin and HR Head can edit
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _editPaymentSlip(slip),
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text('Edit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Remove/Delete button - Admin and HR Head can delete
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _removeEmployeePaymentSlip(slip),
                  icon: const Icon(Icons.delete, size: 20),
                  label: const Text('Remove Employee', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _editPaymentSlip(PaymentSlip slip) async {
    final salaryController = TextEditingController(text: slip.salary.toStringAsFixed(2));
    final allowancesController = TextEditingController(text: slip.allowances.toStringAsFixed(2));
    final epfController = TextEditingController(text: slip.epfContribution.toStringAsFixed(2));
    final overtimePayController = TextEditingController(text: slip.overtimePay.toStringAsFixed(2));
    final overtimeHoursController = TextEditingController(text: slip.overtimeHours.toStringAsFixed(2));
    final isAdminSlip = slip.role == 'admin';
    
    void disposeControllers() {
      try {
        salaryController.dispose();
        allowancesController.dispose();
        epfController.dispose();
        overtimePayController.dispose();
        overtimeHoursController.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }
    
    try {
      final result = await showDialog<Map<String, double>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Edit Payment Slip - ${slip.userFullName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${slip.monthDisplay} ${slip.year}', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: salaryController,
                    decoration: const InputDecoration(labelText: 'Basic Salary', border: OutlineInputBorder(), prefixText: 'Rs '),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      if (isAdminSlip) {
                        final hours = double.tryParse(overtimeHoursController.text.replaceAll(',', '')) ?? 0.0;
                        final salary = double.tryParse(salaryController.text.replaceAll(',', '')) ?? slip.salary;
                        final calculatedOvertimePay = hours * (salary * 0.05);
                        overtimePayController.text = calculatedOvertimePay.toStringAsFixed(2);
                      }
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: allowancesController,
                    decoration: const InputDecoration(labelText: 'Allowances', border: OutlineInputBorder(), prefixText: 'Rs '),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: epfController,
                    decoration: const InputDecoration(labelText: 'EPF Contribution', border: OutlineInputBorder(), prefixText: 'Rs '),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (isAdminSlip) ...[
                    TextField(
                      controller: overtimeHoursController,
                      decoration: const InputDecoration(
                        labelText: 'Overtime Hours *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter overtime hours (e.g., 10.5)',
                        helperText: 'Manually enter overtime hours (not from attendance system)',
                        prefixIcon: Icon(Icons.access_time, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        final hours = double.tryParse(overtimeHoursController.text.replaceAll(',', '')) ?? 0.0;
                        final salary = double.tryParse(salaryController.text.replaceAll(',', '')) ?? slip.salary;
                        final calculatedOvertimePay = hours * (salary * 0.05);
                        overtimePayController.text = calculatedOvertimePay.toStringAsFixed(2);
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overtime Hours:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                          Text('${slip.overtimeHours.toStringAsFixed(2)} hrs', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text('Overtime hours are retrieved from attendance system', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: overtimePayController,
                    decoration: InputDecoration(
                      labelText: 'Overtime Pay',
                      border: const OutlineInputBorder(),
                      prefixText: 'Rs ',
                      helperText: isAdminSlip ? 'Auto-calculated from overtime hours (Overtime Hours × Basic Salary × 5%)' : null,
                      enabled: !isAdminSlip,
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Net Salary (Auto-calculated)', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          'Rs ${_calculateNetSalary(
                            double.tryParse(salaryController.text.replaceAll(',', '')) ?? slip.salary,
                            double.tryParse(allowancesController.text.replaceAll(',', '')) ?? slip.allowances,
                            double.tryParse(epfController.text.replaceAll(',', '')) ?? slip.epfContribution,
                            double.tryParse(overtimePayController.text.replaceAll(',', '')) ?? slip.overtimePay,
                          ).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                        ),
                        const SizedBox(height: 4),
                        Text('Formula: Basic Salary - EPF + Allowances + Overtime Pay', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final salary = double.tryParse(salaryController.text.replaceAll(',', ''));
                  final allowances = double.tryParse(allowancesController.text.replaceAll(',', ''));
                  final epf = double.tryParse(epfController.text.replaceAll(',', ''));
                  final overtimePay = double.tryParse(overtimePayController.text.replaceAll(',', ''));
                  
                  if (salary == null || salary < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(child: Text('Please enter a valid basic salary')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }
                  
                  final resultMap = {'salary': salary, 'allowances': allowances ?? 0.0, 'epf_contribution': epf ?? 0.0, 'overtime_pay': overtimePay ?? 0.0};
                  
                  if (isAdminSlip) {
                    final overtimeHours = double.tryParse(overtimeHoursController.text.replaceAll(',', ''));
                    if (overtimeHours == null || overtimeHours < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.error, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(child: Text('Please enter a valid overtime hours value')),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      return;
                    }
                    resultMap['overtime_hours'] = overtimeHours;
                  }
                  
                  Navigator.pop(context, resultMap);
                },
                child: const Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
      
      if (result == null) {
        Future.delayed(const Duration(seconds: 2), disposeControllers);
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      
      try {
        final updateResult = await ApiService.updatePaymentSlip(
          slipId: slip.id,
          salary: result['salary'],
          allowances: result['allowances'],
          epfContribution: result['epf_contribution'],
          overtimePay: result['overtime_pay'],
          overtimeHours: result.containsKey('overtime_hours') ? result['overtime_hours'] : null,
        );
        
        if (!mounted) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        
        if (updateResult['success'] == true || updateResult['success'] != false) {
          await _loadPaymentSlips();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('Payment slip updated successfully!')),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          final errorMessage = updateResult['message'] ?? updateResult['error'] ?? 'Failed to update payment slip';
          if (mounted && errorMessage.isNotEmpty && !errorMessage.toLowerCase().contains('warning') && !errorMessage.toLowerCase().contains('info') && !errorMessage.toLowerCase().contains('success')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMessage)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (mounted) {
            await _loadPaymentSlips();
          }
        }
      } catch (updateError) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        final errorString = updateError.toString();
        if (mounted && !errorString.contains('TextEditingController') && !errorString.contains('disposed')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error updating payment slip: $updateError')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (mounted) {
          await _loadPaymentSlips();
        }
      } finally {
        Future.delayed(const Duration(seconds: 2), disposeControllers);
      }
    } catch (e) {
      Future.delayed(const Duration(seconds: 2), disposeControllers);
      final errorString = e.toString();
      if (mounted && !errorString.contains('TextEditingController') && !errorString.contains('disposed')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error editing payment slip: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _removeEmployeePaymentSlip(PaymentSlip slip) async {
    final role = _userRole ?? widget.role;
    final isHRHead = role == 'hr_head';
    final isAdmin = role == 'admin';

    // For HR Head, create a removal request instead of directly deleting
    if (isHRHead) {
      final reasonController = TextEditingController();
      
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Request Employee Removal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are requesting the removal of ${slip.userFullName} (Employee ${slip.employeeNumber ?? slip.userId}).',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for removal',
                      border: OutlineInputBorder(),
                      hintText: 'Enter reason for removal request...',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
      
      if (confirm != true) return;
      
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      
      try {
        final requestResult = await ApiService.createRemovalRequest(
          userId: slip.userId,
          reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
        );
        if (!mounted) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        reasonController.dispose();
        
        if (requestResult['success']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(requestResult['message'] ?? 'Removal request submitted successfully!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(requestResult['message'] ?? 'Failed to submit removal request'),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (requestError) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        reasonController.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error submitting removal request: $requestError')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }
    
    // For admin, directly delete (existing behavior)
    if (isAdmin) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Employee'),
          content: Text('Are you sure you want to remove ${slip.userFullName} (Employee #${slip.employeeNumber ?? slip.userId}) from the database?\n\nThis will permanently delete:\n• The employee account\n• All payment slips\n• All related data\n\nThis action cannot be undone.', style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove Employee'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)),
          ],
        ),
      );
      
      if (confirm != true) return;
      
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      
      try {
        final deleteResult = await ApiService.deleteUser(userId: slip.userId);
        if (!mounted) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        
        if (deleteResult['success']) {
          await _loadPaymentSlips();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(deleteResult['message'] ?? 'Employee removed successfully from database!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(deleteResult['message'] ?? 'Failed to remove employee'),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (deleteError) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error removing employee: $deleteError')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  double _calculateNetSalary(double salary, double allowances, double epf, double overtimePay) {
    return salary - epf + allowances + overtimePay;
  }

  Future<void> _downloadPaymentSlipPDF(PaymentSlip slip) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Generate PDF
      final pdfBytes = await _generatePaymentSlipPDF(slip);

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      // Get the directory for saving the file
      Directory? directory;
      if (Platform.isAndroid) {
        // For Android, use the Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to app documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        // For iOS, use the app documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For other platforms (web, desktop)
        directory = await getApplicationDocumentsDirectory();
      }

      // Create filename
      final monthNames = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final monthName = monthNames[slip.month] ?? 'Unknown';
      final fileName = 'PaymentSlip_${slip.userFullName.replaceAll(' ', '_')}_${monthName}_${slip.year}.pdf';
      final filePath = '${directory.path}/$fileName';

      // Save PDF to file
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Verify file was saved
      if (!await file.exists()) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Error: PDF file was not saved correctly')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        // Show success dialog with options
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('What would you like to do?'),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          // Show PDF viewer
                          _showPDFViewer(context, filePath, fileName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.picture_as_pdf, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'View PDF',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final xFile = XFile(filePath);
                            await Share.shareXFiles(
                              [xFile],
                              text: 'Payment Slip - ${slip.userFullName} - $monthName ${slip.year}',
                              subject: 'Payment Slip - ${slip.userFullName}',
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.warning, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Could not share file: $e')),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.share, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Share',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error generating PDF: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<Uint8List> _generatePaymentSlipPDF(PaymentSlip slip) async {
    final pdf = pw.Document();
    final monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final monthName = monthNames[slip.month] ?? 'Unknown';
    final dateFormat = DateFormat('dd MMM yyyy');
    final generatedDate = dateFormat.format(slip.generatedAt);
    
    // Debug: Print payment slip data
    print('📄 Generating PDF for payment slip:');
    print('   - Employee: ${slip.userFullName}');
    print('   - Logo URL: ${slip.companyLogoUrl ?? "Not provided"}');
    
    // Try to load company logo from URL if available
    pw.ImageProvider? logoImage;
    if (slip.companyLogoUrl != null && slip.companyLogoUrl!.isNotEmpty) {
      try {
        print('🖼️ Attempting to load logo from: ${slip.companyLogoUrl}');
        
        // Get authentication token for the request
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        
        // Prepare headers
        final headers = <String, String>{
          'Content-Type': 'application/json',
        };
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        
        final response = await http.get(
          Uri.parse(slip.companyLogoUrl!),
          headers: headers,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Logo loading timeout');
          },
        );
        
        print('🖼️ Logo response status: ${response.statusCode}');
        print('🖼️ Logo response headers: ${response.headers}');
        
        if (response.statusCode == 200) {
          final logoBytes = response.bodyBytes;
          print('🖼️ Logo loaded successfully, size: ${logoBytes.length} bytes');
          
          // Verify it's a valid image by checking content type or file signature
          if (logoBytes.isNotEmpty) {
            // Check if it's a PNG (starts with PNG signature) or JPEG
            final isPng = logoBytes.length >= 8 && 
                          logoBytes[0] == 0x89 && 
                          logoBytes[1] == 0x50 && 
                          logoBytes[2] == 0x4E && 
                          logoBytes[3] == 0x47;
            final isJpeg = logoBytes.length >= 3 && 
                           logoBytes[0] == 0xFF && 
                           logoBytes[1] == 0xD8 && 
                           logoBytes[2] == 0xFF;
            
            if (isPng || isJpeg) {
              logoImage = pw.MemoryImage(logoBytes);
              print('🖼️ Logo image provider created successfully');
            } else {
              print('⚠️ Logo file is not a valid PNG or JPEG image');
            }
          } else {
            print('⚠️ Logo response is empty');
          }
        } else {
          print('⚠️ Failed to load logo: HTTP ${response.statusCode}');
          print('⚠️ Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        }
      } catch (e, stackTrace) {
        // Logo loading failed, will continue without logo
        print('❌ Failed to load company logo: $e');
        print('❌ Stack trace: $stackTrace');
      }
    } else {
      print('ℹ️ No company logo URL provided in payment slip');
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Formal Letterhead
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.blue700, width: 2),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Company Header with Logo
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Company Logo
                            if (logoImage != null)
                              pw.Container(
                                width: 60,
                                height: 60,
                                child: pw.Image(
                                  logoImage!,
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            if (logoImage != null) pw.SizedBox(width: 12),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'AUDITRA',
                                  style: pw.TextStyle(
                                    fontSize: 32,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Human Resources Department',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'PAYMENT SLIP',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey900,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            if (slip.paySlipNumber != null)
                              pw.Text(
                                'Document No: ${slip.paySlipNumber}',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),
              
              // Document Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Payment Period: $monthName $slip.year',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Text(
                    'Date Generated: $generatedDate',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 25),
              
              // Employee Information Section
              pw.Anchor(
                name: 'employee-info',
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue400, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EMPLOYEE INFORMATION',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildFormalPDFRow('Full Name', slip.userFullName),
                                pw.SizedBox(height: 8),
                                _buildFormalPDFRow('Employee ID', slip.employeeNumber ?? slip.userId.toString()),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildFormalPDFRow('Designation', slip.roleDisplay),
                                pw.SizedBox(height: 8),
                                _buildFormalPDFRow('Employment Status', slip.statusDisplay),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              pw.SizedBox(height: 20),
              
              // Earnings Section
              pw.Anchor(
                name: 'salary-details',
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EARNINGS',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.blue400, width: 1),
                      ),
                      child: pw.Table(
                        border: pw.TableBorder(
                          horizontalInside: pw.BorderSide(color: PdfColors.blue300, width: 0.5),
                        ),
                        children: [
                          _buildFormalTableRow('Basic Salary', _formatCurrency(slip.salary)),
                          _buildFormalTableRow('Allowances', _formatCurrency(slip.allowances)),
                          _buildFormalTableRow('Overtime Hours', '${slip.overtimeHours.toStringAsFixed(2)} hours'),
                          _buildFormalTableRow('Overtime Pay', _formatCurrency(slip.overtimePay)),
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                            ),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text(
                                  'Total Gross Earnings',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text(
                                  _formatCurrency(slip.salary + slip.allowances + slip.overtimePay),
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              pw.SizedBox(height: 20),
              
              // Deductions Section
              pw.Anchor(
                name: 'deductions',
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DEDUCTIONS',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.blue400, width: 1),
                      ),
                      child: pw.Table(
                        border: pw.TableBorder(
                          horizontalInside: pw.BorderSide(color: PdfColors.blue300, width: 0.5),
                        ),
                        children: [
                          _buildFormalTableRow('EPF Contribution (8%)', _formatCurrency(slip.epfContribution)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              pw.SizedBox(height: 25),
              
              // Net Salary Section
              pw.Anchor(
                name: 'net-salary',
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.blue700, width: 2),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'NET SALARY PAYABLE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(slip.netSalary),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              
              // Formal Footer
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.blue700, width: 1),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'This is a computer-generated document and does not require a signature.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.UrlLink(
                          destination: 'mailto:hr@auditra.com',
                          child: pw.Text(
                            'hr@auditra.com',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.blue700,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                        ),
                        pw.Text(
                          ' | ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.UrlLink(
                          destination: 'https://www.auditra.com',
                          child: pw.Text(
                            'www.auditra.com',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.blue700,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Document Reference: ${slip.paySlipNumber ?? 'PS-${slip.id}-${slip.year}-${slip.month}'}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '© ${DateTime.now().year} Auditra. All rights reserved.',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPDFRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFormalPDFRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey900,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildFormalTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey800,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }

  void _showPDFViewer(BuildContext context, String filePath, String fileName) async {
    // Check if file exists
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('PDF file not found. Please generate it again.')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    // Read file bytes
    Uint8List? pdfBytes;
    try {
      pdfBytes = await file.readAsBytes();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error reading PDF file: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(fileName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    try {
                      final xFile = XFile(filePath);
                      await Share.shareXFiles(
                        [xFile],
                        text: 'Payment Slip PDF',
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Could not share file: $e')),
                              ],
                            ),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'Share PDF',
                ),
              ],
            ),
            body: pdfBytes != null
                ? SfPdfViewer.memory(
                    pdfBytes,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                  )
                : const Center(
                    child: Text('Error loading PDF'),
                  ),
          ),
        ),
      );
    }
  }

  Future<void> _uploadPaymentSlip(PaymentSlip slip) async {
    final overtimeHoursController = TextEditingController(text: slip.overtimeHours.toStringAsFixed(2));
    try {
      final result = await showDialog<Map<String, double>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Upload Overtime Hours - ${slip.userFullName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${slip.monthDisplay} ${slip.year}', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  Text(slip.overtimeHoursUploaded ? 'Overtime hours were previously uploaded. Update with new value?' : 'Overtime hours are currently from attendance system. Upload new value?', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  TextField(controller: overtimeHoursController, decoration: const InputDecoration(labelText: 'Overtime Hours', border: OutlineInputBorder(), hintText: 'Enter overtime hours'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Overtime Hours: ${slip.overtimeHours.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(slip.overtimeHoursUploaded ? 'Source: Uploaded' : 'Source: Attendance System', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final overtimeHours = double.tryParse(overtimeHoursController.text.replaceAll(',', ''));
                  if (overtimeHours == null || overtimeHours < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(child: Text('Please enter a valid overtime hours value')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {'overtime_hours': overtimeHours});
                },
                child: const Text('Upload'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
      
      Future.microtask(() => overtimeHoursController.dispose());
      if (result == null) return;
      
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      final uploadResult = await ApiService.uploadOvertimeHours(slipId: slip.id, overtimeHours: result['overtime_hours']!);
      if (!mounted) return;
      Navigator.pop(context);
      
      if (uploadResult['success']) {
        await _loadPaymentSlips();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Overtime hours uploaded successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
                Expanded(
                  child: Text(uploadResult['message'] ?? 'Failed to upload overtime hours'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Future.microtask(() => overtimeHoursController.dispose());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error uploading overtime hours: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildPaymentSlipHeader(PaymentSlip slip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user, size: 60, color: Colors.blue),
                const SizedBox(height: 12),
                const Text('Auditra', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (slip.userFullName.isNotEmpty)
                Text(slip.userFullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 8,
                children: [
                  _buildInfoItem('Employee no', slip.employeeNumber ?? slip.userId.toString()),
                  _buildInfoItem('Pay Slip no', slip.paySlipNumber ?? 'PS-' + slip.year.toString() + slip.month.toString().padLeft(2, '0') + '-' + slip.userId.toString()),
                  _buildInfoItem('Month', '${slip.monthDisplay} ${slip.year}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(slip.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(slip.status), width: 1),
              ),
              child: Text(slip.statusDisplay, style: TextStyle(color: _getStatusColor(slip.status), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]),
        const SizedBox(height: 12),
        if (slip.generatedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text('Generated: ${DateFormat('yyyy-MM-dd').format(slip.generatedAt)}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
      ],
    );
  }

  Widget _buildSalaryBreakdown(PaymentSlip slip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_shouldAlignLeft) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Salary Breakdown', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 16),
            _buildSalaryRow('Basic Salary', slip.salary),
            _buildSalaryRow('Allowances', slip.allowances),
            _buildSalaryRow('EPF Contribution', -slip.epfContribution),
            _buildSalaryRow('Overtime Hours', slip.overtimeHours, isHours: true),
            _buildSalaryRow('Overtime Pay', slip.overtimePay),
            Divider(height: 24, color: isDark ? Colors.white.withOpacity(0.1) : null),
            _buildNetSalaryRow(slip.netSalary),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50], 
          borderRadius: BorderRadius.circular(8), 
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], 
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Salary Breakdown', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            const SizedBox(height: 16),
            _buildSalaryRow('Basic Salary', slip.salary),
            _buildSalaryRow('Allowances', slip.allowances),
            _buildSalaryRow('Overtime Hours', slip.overtimeHours, isHours: true),
            _buildSalaryRow('Overtime Pay', slip.overtimePay),
            Divider(height: 24, thickness: 1.5, color: isDark ? Colors.white.withOpacity(0.1) : null),
            _buildSalaryRow('EPF Contribution', -slip.epfContribution, isDeduction: true),
            const SizedBox(height: 16),
            _buildNetSalaryRow(slip.netSalary),
          ],
        ),
      );
    }
  }

  Widget _buildSalaryRow(String label, double amount, {bool isHours = false, Color? color, bool isDeduction = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount = isHours ? '${amount.toStringAsFixed(1)} hrs' : 'Rs ${NumberFormat('#,##0.00').format(amount.abs())}';
    
    if (_shouldAlignLeft) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('$label:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            Text(formattedAmount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      );
    } else {
      final prefix = isDeduction ? '-' : (amount >= 0 ? '+' : '');
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label:', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.w500)),
            Text(isHours ? formattedAmount : '$prefix$formattedAmount', style: TextStyle(fontSize: 14, fontWeight: isDeduction ? FontWeight.bold : FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      );
    }
  }

  Widget _buildNetSalaryRow(double netSalary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text('Net Salary:', style: TextStyle(fontSize: _shouldAlignLeft ? 16 : 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
        Text('Rs ${NumberFormat('#,##0.00').format(netSalary)}', style: TextStyle(fontSize: _shouldAlignLeft ? 16 : 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildPaymentSlipContent(PaymentSlip slip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue[200]!),
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_user, size: 60, color: Colors.blue),
                const SizedBox(height: 12),
                const Text('Auditra', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 4),
                Text('Payment Slip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50], borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Employee Name', slip.userFullName, isBold: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('Payment Month', slip.monthDisplay)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildInfoRow('Year', slip.year.toString())),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('Pay Slip no', slip.paySlipNumber ?? 'PS-' + slip.year.toString() + slip.month.toString().padLeft(2, '0') + '-' + slip.userId.toString())),
                    const SizedBox(width: 16),
                    Expanded(child: _buildInfoRow('Employee no', slip.employeeNumber ?? slip.userId.toString())),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50], 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Salary Breakdown', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 16),
                _buildSalaryRow('Basic Salary', slip.salary),
                const SizedBox(height: 12),
                _buildSalaryRow('Allowances', slip.allowances),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Overtime Hours:', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                    Text('${slip.overtimeHours.toStringAsFixed(1)} hrs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[200] : Colors.grey[800])),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSalaryRow('Overtime Pay', slip.overtimePay),
                const SizedBox(height: 12),
                Divider(color: isDark ? Colors.white.withOpacity(0.1) : null),
                const SizedBox(height: 12),
                _buildSalaryRow('EPF Contribution (8%)', -slip.epfContribution, isDeduction: true),
                const SizedBox(height: 16),
                _shouldAlignLeft
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: Text('Net Salary:', textAlign: TextAlign.left, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                          Text('Rs ${NumberFormat('#,##,###').format(slip.netSalary)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Net Salary:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          Text('Rs. ${NumberFormat('#,##,###').format(slip.netSalary)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.white.withOpacity(0.1) : null),
          const SizedBox(height: 12),
          _buildDetailRow('Role', slip.roleDisplay),
          _buildDetailRow('Status', slip.statusDisplay),
          _buildDetailRow('Generated At', DateFormat('MMM dd, yyyy HH:mm').format(slip.generatedAt)),
          if (slip.generatedByUsername != null) _buildDetailRow('Generated By', slip.generatedByUsername!),
          if (slip.paidAt != null) _buildDetailRow('Paid At', DateFormat('MMM dd, yyyy HH:mm').format(slip.paidAt!)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14))),
          Expanded(child: Text(value, style: TextStyle(fontSize: isHighlight ? 16 : 14, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal, color: isHighlight ? (isDark ? const Color(0xFF10B981) : Colors.green[700]) : (isDark ? Colors.white70 : Colors.black87)))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'generated': return Colors.blue;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid': return Icons.check_circle;
      case 'generated': return Icons.description;
      case 'pending': return Icons.pending;
      default: return Icons.help_outline;
    }
  }
}