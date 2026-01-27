class AdminData {
  const AdminData({
    required this.id,
    required this.userId,
    required this.role,
    required this.isActive,
    required this.permissions,
    required this.raw,
  });

  final String id;
  final String userId;
  final String role;
  final bool isActive;
  final Map<String, dynamic> permissions;
  final Map<String, dynamic> raw;

  bool get isSuperAdmin => role == 'super_admin';

  factory AdminData.fromJson(Map<String, dynamic> json) {
    return AdminData(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      isActive: json['is_active'] == true,
      permissions: (json['permissions'] as Map?)?.cast<String, dynamic>() ?? const {},
      raw: json,
    );
  }
}
