import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(SupabaseService.client);
});

final activeAdminProvider = FutureProvider<AdminData?>((ref) async {
  final User? user = SupabaseService.client.auth.currentUser;
  if (user == null) return null;
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getActiveAdminByUserId(user.id);
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(activeAdminProvider).valueOrNull != null;
});

final isSuperAdminProvider = Provider<bool>((ref) {
  final admin = ref.watch(activeAdminProvider).valueOrNull;
  return admin?.isSuperAdmin ?? false;
});

final adminActionControllerProvider =
    StateNotifierProvider<AdminActionController, bool>((ref) {
      return AdminActionController(ref.watch(adminRepositoryProvider), ref);
    });

class AdminActionController extends StateNotifier<bool> {
  AdminActionController(this._repo, this._ref) : super(false);

  final AdminRepository _repo;
  final Ref _ref;

  Future<String?> logAction({
    required String actionType,
    required String targetType,
    String? targetId,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      state = true;

      final admin = await _ref.read(activeAdminProvider.future);
      if (admin == null) return 'Not an admin';

      await _repo.logAdminAction(
        adminId: admin.id,
        actionType: actionType,
        targetType: targetType,
        targetId: targetId,
        details: details,
      );
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      state = false;
    }
  }
}
