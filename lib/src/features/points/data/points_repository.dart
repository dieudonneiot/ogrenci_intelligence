
import '../../../core/supabase/supabase_service.dart';
import '../domain/points_models.dart';

class PointsRepository {
  const PointsRepository({this.onPointsAwarded});

  final void Function()? onPointsAwarded;

  Future<int> fetchTotalPoints({required String userId}) async {
    final res = await SupabaseService.client
        .from('profiles')
        .select('total_points')
        .eq('user_id', userId)
        .maybeSingle();

    if (res == null) return 0;
    final v = res['total_points'];
    return (v is int) ? v : (v as num?)?.toInt() ?? 0;
  }

  Future<List<UserPoint>> fetchUserPoints({required String userId, int limit = 80}) async {
    final rows = await SupabaseService.client
        .from('user_points')
        .select('id, user_id, source, description, points, created_at')
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
        .select('id, user_id, badge_type, badge_title, badge_description, icon, earned_at, points_awarded')
        .eq('user_id', userId)
        .order('earned_at', ascending: false);

    return (rows as List).map((e) => UserBadge.fromMap(e as Map<String, dynamic>)).toList();
  }

  /* ----------------------- WRITE / AWARD METHODS ---------------------- */

  /// Adds points in a "React-equivalent" way:
  /// 1) insert into user_points
  /// 2) insert into activity_logs
  /// 3) update profiles.total_points ONLY if your DB doesn't already do it (trigger, etc.)
  Future<void> addActivityAndPoints({
    required String userId,
    required String category, // activity_logs.category (ex: "platform")
    required String action,   // activity_logs.action (human text shown in UI)
    required int points,
    required String source,   // user_points.source (ex: "platform")
    String? description,      // user_points.description
    Map<String, dynamic>? metadata, // activity_logs.metadata
  }) async {
    final before = await fetchTotalPoints(userId: userId);

    // Insert user_points
    await SupabaseService.client.from('user_points').insert({
      'user_id': userId,
      'source': source,
      'description': description,
      'points': points,
    });

    // Insert activity_logs (no description column in schema, so keep action user-friendly)
    await SupabaseService.client.from('activity_logs').insert({
      'user_id': userId,
      'category': category,
      'action': action,
      'points': points,
      'metadata': metadata,
    });

    // If DB doesn't auto-update total_points, do it here.
    final after = await fetchTotalPoints(userId: userId);

    // If total_points didn't move, we update it ourselves (common when no trigger exists).
    if (after == before) {
      await SupabaseService.client
          .from('profiles')
          .update({'total_points': before + points})
          .eq('user_id', userId);
    }

    onPointsAwarded?.call();
  }

  /* ------------------------- DASHBOARD BONUSES ------------------------ */

  /// Daily bonus logic:
  /// If no activity_logs row exists today with metadata.code = "daily_login" -> award +2
  Future<bool> checkDailyLoginBonus({required String userId}) async {
    final nowUtc = DateTime.now().toUtc();
    final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final existing = await SupabaseService.client
        .from('activity_logs')
        .select('id')
        .eq('user_id', userId)
        .contains('metadata', {'code': 'daily_login'})
        .gte('created_at', todayStart.toIso8601String())
        .lt('created_at', tomorrowStart.toIso8601String())
        .limit(1);

    final alreadyAwarded = (existing as List).isNotEmpty;
    if (alreadyAwarded) return false;

    await addActivityAndPoints(
      userId: userId,
      category: 'platform',
      action: 'Gunluk giris bonusu',
      points: 2,
      source: 'platform',
      description: 'Gunluk giris bonusu',
      metadata: {'code': 'daily_login'},
    );

    return true;
  }

  /// Weekly streak logic:
  /// If the user has "daily_login" on 7 UNIQUE days in last 7 calendar days
  /// and no "weekly_streak" exists in same window -> award +15
  Future<bool> checkWeeklyStreakBonus({required String userId}) async {
    final nowUtc = DateTime.now().toUtc();
    final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final windowStart = todayStart.subtract(const Duration(days: 6)); // 7 calendar days incl. today
    final windowEnd = todayStart.add(const Duration(days: 1));        // tomorrow 00:00

    final dailyLogs = await SupabaseService.client
        .from('activity_logs')
        .select('created_at')
        .eq('user_id', userId)
        .contains('metadata', {'code': 'daily_login'})
        .gte('created_at', windowStart.toIso8601String())
        .lt('created_at', windowEnd.toIso8601String())
        .order('created_at', ascending: false);

    final uniqueDays = <String>{};
    for (final row in (dailyLogs as List)) {
      final raw = (row as Map<String, dynamic>)['created_at']?.toString();
      final dt = DateTime.tryParse(raw ?? '');
      if (dt == null) continue;

      final d = dt.toUtc();
      uniqueDays.add('${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}');
    }

    if (uniqueDays.length < 7) return false;

    final existingReward = await SupabaseService.client
        .from('activity_logs')
        .select('id')
        .eq('user_id', userId)
        .contains('metadata', {'code': 'weekly_streak'})
        .gte('created_at', windowStart.toIso8601String())
        .lt('created_at', windowEnd.toIso8601String())
        .limit(1);

    final alreadyRewarded = (existingReward as List).isNotEmpty;
    if (alreadyRewarded) return false;

    await addActivityAndPoints(
      userId: userId,
      category: 'platform',
      action: '7 gunluk seri bonusu',
      points: 15,
      source: 'platform',
      description: '7 gun ust uste giris yaptiniz!',
      metadata: {'code': 'weekly_streak'},
    );

    return true;
  }
}
