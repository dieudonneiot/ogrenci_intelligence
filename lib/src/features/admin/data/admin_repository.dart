import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<AdminData?> getActiveAdminByUserId(String userId) async {
    final row = await _client
        .from('admins')
        .select('*')
        .eq('id', userId)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) return null;
    return AdminData.fromJson(row);
  }

  Future<void> logAdminAction({
    required String adminId,
    required String actionType,
    required String targetType,
    String? targetId,
    Map<String, dynamic> details = const {},
  }) async {
    await _client.from('admin_logs').insert({
      'admin_id': adminId,
      'action_type': actionType,
      'target_type': targetType,
      'target_id': targetId,
      'details': details,
      // On mobile, don't pretend we have the public IP.
      'ip_address': null,
    });
  }
}
