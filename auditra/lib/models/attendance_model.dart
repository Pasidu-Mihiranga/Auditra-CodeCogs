class Attendance {
  final int? id;
  final int userId;
  final String userUsername;
  final String? userFullName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? overtimeStart;
  final DateTime? overtimeEnd;
  final String status;
  final String statusDisplay;
  final double workingHours;
  final double overtimeHours;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Attendance({
    this.id,
    required this.userId,
    required this.userUsername,
    this.userFullName,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.overtimeStart,
    this.overtimeEnd,
    required this.status,
    required this.statusDisplay,
    required this.workingHours,
    required this.overtimeHours,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      userId: json['user'],
      userUsername: json['user_username'] ?? '',
      userFullName: json['user_full_name'],
      date: DateTime.parse(json['date']),
      checkIn: json['check_in'] != null ? DateTime.parse(json['check_in']) : null,
      checkOut: json['check_out'] != null ? DateTime.parse(json['check_out']) : null,
      overtimeStart: json['overtime_start'] != null ? DateTime.parse(json['overtime_start']) : null,
      overtimeEnd: json['overtime_end'] != null ? DateTime.parse(json['overtime_end']) : null,
      status: json['status'] ?? 'absent',
      statusDisplay: json['status_display'] ?? 'Absent',
      workingHours: _parseDouble(json['working_hours']),
      overtimeHours: _parseDouble(json['overtime_hours']),
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  bool get isPresent => status == 'present';
  bool get isHalfDay => status == 'half_day';
  bool get isAbsent => status == 'absent';
  bool get isCheckedIn => checkIn != null;
  bool get isCheckedOut => checkOut != null;
  bool get isOvertimeActive => overtimeStart != null && overtimeEnd == null;
  bool get hasOvertime => overtimeStart != null;
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class AttendanceSummary {
  final int totalDays;
  final int workingDays;
  final int presentDays;
  final int halfDays;
  final int absentDays;
  final double totalWorkingHours;
  final double totalOvertimeHours;
  final double attendancePercentage;
  final List<DailyAttendanceData> dailyData;

  AttendanceSummary({
    required this.totalDays,
    required this.workingDays,
    required this.presentDays,
    required this.halfDays,
    required this.absentDays,
    required this.totalWorkingHours,
    required this.totalOvertimeHours,
    required this.attendancePercentage,
    required this.dailyData,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] ?? {};
    final dailyDataList = json['daily_data'] as List<dynamic>? ?? [];
    
    return AttendanceSummary(
      totalDays: json['total_days'] ?? 0,
      workingDays: json['working_days'] ?? 0,
      presentDays: summary['present'] ?? 0,
      halfDays: summary['half_day'] ?? 0,
      absentDays: summary['absent'] ?? 0,
      totalWorkingHours: Attendance._parseDouble(summary['total_working_hours']),
      totalOvertimeHours: Attendance._parseDouble(summary['total_overtime_hours']),
      attendancePercentage: Attendance._parseDouble(summary['attendance_percentage']),
      dailyData: dailyDataList.map((item) => DailyAttendanceData.fromJson(item)).toList(),
    );
  }
}

class DailyAttendanceData {
  final DateTime date;
  final String status;
  final double workingHours;
  final double overtimeHours;

  DailyAttendanceData({
    required this.date,
    required this.status,
    required this.workingHours,
    required this.overtimeHours,
  });

  factory DailyAttendanceData.fromJson(Map<String, dynamic> json) {
    return DailyAttendanceData(
      date: DateTime.parse(json['date']),
      status: json['status'] ?? 'absent',
      workingHours: Attendance._parseDouble(json['working_hours']),
      overtimeHours: Attendance._parseDouble(json['overtime_hours']),
    );
  }
}

