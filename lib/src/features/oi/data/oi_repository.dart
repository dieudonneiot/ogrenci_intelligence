import '../../../core/supabase/supabase_service.dart';
import '../domain/oi_models.dart';

class OiRepository {
  const OiRepository();

  Future<OiProfile> fetchMyOiProfile({required String userId}) async {
    if (userId.isEmpty) {
      throw Exception('Missing userId');
    }

    try {
      await SupabaseService.client.rpc('ensure_my_oi_profile');
    } catch (_) {
      // Ignore (table/function might not exist yet in some envs)
    }

    final row = await SupabaseService.client
        .from('oi_scores')
        .select('user_id,oi_score,technical,social,field_fit,consistency,updated_at')
        .eq('user_id', userId)
        .maybeSingle();

    final base = row == null ? OiProfile.defaultFor(userId) : OiProfile.fromMap(row);

    // Trend data (best-effort): requires docs/sql/22_oi_score_history.sql
    try {
      final raw = await SupabaseService.client.rpc(
        'get_my_oi_history',
        params: const {'limit_count': 6},
      );

      final list = (raw is List) ? raw : const <dynamic>[];
      final points = list
          .whereType<Map<String, dynamic>>()
          .map(OiHistoryPoint.fromMap)
          .toList(growable: false);

      final delta = points.length >= 2 ? (points[0].oiScore - points[1].oiScore) : 0;

      return OiProfile(
        userId: base.userId,
        oiScore: base.oiScore,
        technical: base.technical,
        social: base.social,
        fieldFit: base.fieldFit,
        consistency: base.consistency,
        updatedAt: base.updatedAt,
        deltaFromLastMonth: delta,
        history: points,
      );
    } catch (_) {
      return base;
    }
  }
}
