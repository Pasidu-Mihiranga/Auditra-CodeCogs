class UserRole {
  final String role;
  final String roleDisplay;
  final String? assignedBy;
  final DateTime? assignedAt;

  UserRole({
    required this.role,
    required this.roleDisplay,
    this.assignedBy,
    this.assignedAt,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      role: json['role'] ?? 'unassigned',
      roleDisplay: json['role_display'] ?? 'Unassigned',
      assignedBy: json['assigned_by_username'],
      assignedAt: json['assigned_at'] != null 
          ? DateTime.parse(json['assigned_at'])
          : null,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isUnassigned => role == 'unassigned';
}

class UserModel {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role;
  final String roleDisplay;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.role,
    required this.roleDisplay,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      role: json['role'] ?? 'unassigned',
      roleDisplay: json['role_display'] ?? 'Unassigned',
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username;
  }

  bool get isAdmin => role == 'admin';
  bool get isUnassigned => role == 'unassigned';
}

class RoleOption {
  final String value;
  final String label;

  RoleOption({required this.value, required this.label});

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      value: json['value'],
      label: json['label'],
    );
  }
}

