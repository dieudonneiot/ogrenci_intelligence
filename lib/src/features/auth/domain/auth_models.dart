enum UserType { guest, student, company, admin }

class CompanyMembership {
  const CompanyMembership({
    required this.companyId,
    required this.role,
  });

  final String companyId;
  final String role;

  factory CompanyMembership.fromJson(Map<String, dynamic> json) {
    return CompanyMembership(
      companyId: json['company_id'].toString(),
      role: (json['role'] ?? '').toString(),
    );
  }
}
