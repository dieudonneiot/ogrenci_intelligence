import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<bool> isCurrentUserAdmin() async {
    try {
      final res = await _client.rpc('is_admin');
      if (res is bool) return res;
      if (res is num) return res != 0;
      if (res is String) {
        final v = res.trim().toLowerCase();
        if (v == 'true') return true;
        if (v == 'false') return false;
      }
      return false;
    } catch (_) {
      // Fallback if RPC doesn't exist yet (legacy DB): try reading the table.
      final uid = _client.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return false;
      try {
        final row = await _client
            .from('admins')
            .select('id')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle();
        return row != null;
      } catch (_) {
        return false;
      }
    }
  }

  Future<AdminData?> getActiveAdminByUserId(String userId) async {
    final row = await _client
        .from('admins')
        .select('*')
        .eq('user_id', userId)
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
