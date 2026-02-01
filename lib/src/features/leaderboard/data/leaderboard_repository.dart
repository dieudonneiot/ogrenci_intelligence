import '../../../core/supabase/supabase_service.dart';
import '../domain/leaderboard_models.dart';

class LeaderboardRepository {
  const LeaderboardRepository();

  Future<Map<String, dynamic>?> fetchMyProfile({required String userId}) async {
    final row = await SupabaseService.client
        .from('profiles')
        .select('id, full_name, email, department, total_points')
        .eq('id', userId)
        .maybeSingle();

    return row;
  }

  Future<List<LeaderboardEntry>> fetchOverall({int limit = 50}) async {
    final rows = await SupabaseService.client
        .from('profiles')
        .select('id, full_name, email, department, total_points')
        .order('total_points', ascending: false)
        .limit(limit);

    final list = (rows as List)
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: false);

    return List.generate(
      list.length,
      (i) => LeaderboardEntry.fromProfileMap(list[i], rank: i + 1),
    );
  }

  Future<List<LeaderboardEntry>> fetchByDepartment({
    required String department,
    int limit = 50,
  }) async {
    final rows = await SupabaseService.client
        .from('profiles')
        .select('id, full_name, email, department, total_points')
        .eq('department', department)
        .order('total_points', ascending: false)
        .limit(limit);

    final list = (rows as List)
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: false);

    return List.generate(
      list.length,
      (i) => LeaderboardEntry.fromProfileMap(list[i], rank: i + 1),
    );
  }
}
