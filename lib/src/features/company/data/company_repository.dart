import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyRepository {
  CompanyRepository(this._client);

  final SupabaseClient _client;

  /// Returns membership if the current user belongs to a company.
  /// Mirrors React: supabase.from("company_users").select("company_id, role").eq("user_id", user.id).maybeSingle()
  Future<({String companyId, String role})?> getMembershipByUserId(String userId) async {
    final row = await _client
        .from('company_users')
        .select('company_id, role')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    return (
      companyId: row['company_id'].toString(),
      role: (row['role'] ?? '').toString(),
    );
  }

  /// Optional: get company basic profile (we'll expand later based on your DB schema).
  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    final row = await _client
        .from('companies')
        .select('*')
        .eq('id', companyId)
        .maybeSingle();
    return row;
  }
}
