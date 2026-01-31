
import '../../../core/supabase/supabase_service.dart';
import '../domain/points_models.dart';

class PointsRepository {
  const PointsRepository();

  Future<int> fetchTotalPoints({required String userId}) async {
    final res = await SupabaseService.client
        .from('profiles')
        .select('total_points')
        .eq('user_id', userId)
        .maybeSingle();

    if (res == null) return 0;
    return (res['total_points'] ?? 0) as int;
  }

  Future<List<UserPoint>> fetchUserPoints({required String userId, int limit = 80}) async {
    final rows = await SupabaseService.client
        .from('user_points')
        .select('id, source, description, points, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List).map((e) => UserPoint.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Reward>> fetchRewards() async {
    final rows = await SupabaseService.client
        .from('rewards')
        .select('id, title, description, required_points, department, icon')
        .order('required_points', ascending: true);

    return (rows as List).map((e) => Reward.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserBadge>> fetchBadges({required String userId}) async {
    final rows = await SupabaseService.client
        .from('user_badges')
        .select('id, badge_type, badge_title, badge_description, icon, earned_at, points_awarded')
        .eq('user_id', userId)
        .order('earned_at', ascending: false);

    return (rows as List).map((e) => UserBadge.fromMap(e as Map<String, dynamic>)).toList();
  }
}
