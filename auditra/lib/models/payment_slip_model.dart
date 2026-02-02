class PaymentSlip {
  final int id;
  final int userId;
  final String userUsername;
  final String userFullName;
  final int month;
  final String monthDisplay;
  final int year;
  final double salary; // Basic salary
  final double allowances; // Total allowances
  final double epfContribution; // EPF 8% of basic
  final double overtimeHours; // Total overtime hours for the month
  final bool overtimeHoursUploaded; // Flag to track if overtime hours were uploaded manually
  final double overtimePay; // Overtime payment
  final double netSalary; // Net salary (basic + allowances + overtime - EPF)
  final String role;
  final String roleDisplay;
  final String? paySlipNumber;
  final String? employeeNumber;
  final String status;
  final int? generatedById;
  final String? generatedByUsername;
  final DateTime generatedAt;
  final DateTime? paidAt;
  final String? companyLogoUrl;

  PaymentSlip({
    required this.id,
    required this.userId,
    required this.userUsername,
    required this.userFullName,
    required this.month,
    required this.monthDisplay,
    required this.year,
    required this.salary,
    required this.allowances,
    required this.epfContribution,
    required this.overtimeHours,
    required this.overtimeHoursUploaded,
    required this.overtimePay,
    required this.netSalary,
    required this.role,
    required this.roleDisplay,
    this.paySlipNumber,
    this.employeeNumber,
    required this.status,
    this.generatedById,
    this.generatedByUsername,
    required this.generatedAt,
    this.paidAt,
    this.companyLogoUrl,
  });

  factory PaymentSlip.fromJson(Map<String, dynamic> json) {
    try {
      // Helper function to parse decimal values
      double _parseDecimal(dynamic value) {
        if (value == null) return 0.0;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }
      
      return PaymentSlip(
        id: json['id'] as int,
        userId: json['user'] as int,
        userUsername: (json['user_username'] ?? '') as String,
        userFullName: (json['user_full_name'] ?? '') as String,
        month: json['month'] as int,
        monthDisplay: (json['month_display'] ?? _getMonthName(json['month'] as int)) as String,
        year: json['year'] as int,
        salary: _parseDecimal(json['salary']),
        allowances: _parseDecimal(json['allowances']),
        epfContribution: _parseDecimal(json['epf_contribution']),
        overtimeHours: _parseDecimal(json['overtime_hours']),
        overtimeHoursUploaded: json['overtime_hours_uploaded'] as bool? ?? false,
        overtimePay: _parseDecimal(json['overtime_pay']),
        netSalary: _parseDecimal(json['net_salary']),
        role: (json['role'] ?? '') as String,
        roleDisplay: (json['role_display'] ?? '') as String,
        paySlipNumber: json['pay_slip_number'] as String?,
        employeeNumber: json['employee_number'] as String?,
        status: (json['status'] ?? 'generated') as String,
        generatedById: json['generated_by'] as int?,
        generatedByUsername: json['generated_by_username'] as String?,
        generatedAt: DateTime.parse(json['generated_at'] as String),
        paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
        companyLogoUrl: json['company_logo_url'] as String?,
      );
    } catch (e, stackTrace) {
      print('Error parsing PaymentSlip: $e');
      print('JSON data: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month] ?? 'Unknown';
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'generated':
        return 'Generated';
      case 'paid':
        return 'Paid';
      default:
        return status;
    }
  }
}

