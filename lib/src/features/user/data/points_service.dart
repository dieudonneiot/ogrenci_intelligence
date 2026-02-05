import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';

class LoginBonusResult {
  const LoginBonusResult({
    required this.dailyAwarded,
    required this.weeklyAwarded,
    required this.currentStreak,
  });

  final bool dailyAwarded;
  final bool weeklyAwarded;
  final int currentStreak;
}

class PointsService {
  const PointsService();

  static const int dailyLoginPoints = 2;
  static const int weeklyStreakPoints = 15;

  Future<LoginBonusResult> checkLoginBonuses({required String userId}) async {
    final daily = await _checkDailyLogin(userId: userId);
    final weekly = await _checkWeeklyStreak(userId: userId);
    return LoginBonusResult(
      dailyAwarded: daily,
      weeklyAwarded: weekly.weeklyAwarded,
      currentStreak: weekly.currentStreak,
    );
  }

  Future<bool> _checkDailyLogin({required String userId}) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));

      final existing = await SupabaseService.client
          .from('activity_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('action', 'daily_login')
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', tomorrowStart.toIso8601String());

      final hasToday = (existing as List).isNotEmpty;
      if (hasToday) return false;

      await _addActivityAndPoints(
        userId: userId,
        category: 'platform',
        action: 'daily_login',
        points: dailyLoginPoints,
        description: 'Günlük giriş bonusu',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<({bool weeklyAwarded, int currentStreak})> _checkWeeklyStreak({
    required String userId,
  }) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final sevenDaysAgo = nowUtc.subtract(const Duration(days: 7));

      final logs = await SupabaseService.client
          .from('activity_logs')
          .select('created_at')
          .eq('user_id', userId)
          .eq('action', 'daily_login')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: false);

      final dayKey = DateFormat('yyyy-MM-dd');
      final uniqueDays = <String>{};
      for (final entry in (logs as List)) {
        final row = entry as Map<String, dynamic>;
        final dt = DateTime.tryParse(row['created_at']?.toString() ?? '');
        if (dt != null) uniqueDays.add(dayKey.format(dt.toUtc()));
      }

      final streak = uniqueDays.length;

      if (streak >= 7) {
        final existingReward = await SupabaseService.client
            .from('activity_logs')
            .select('id')
            .eq('user_id', userId)
            .eq('action', 'weekly_streak')
            .gte('created_at', sevenDaysAgo.toIso8601String())
            .maybeSingle();

        if (existingReward == null) {
          await _addActivityAndPoints(
            userId: userId,
            category: 'platform',
            action: 'weekly_streak',
            points: weeklyStreakPoints,
            description: '7 gün üst üste giriş yaptınız!',
          );
          return (weeklyAwarded: true, currentStreak: streak);
        }
      }

      return (weeklyAwarded: false, currentStreak: streak);
    } catch (_) {
      return (weeklyAwarded: false, currentStreak: 0);
    }
  }

  Future<void> _addActivityAndPoints({
    required String userId,
    required String category,
    required String action,
    required int points,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    // Matches React: supabase.rpc('add_activity_and_points', ...)
    await SupabaseService.client.rpc(
      'add_activity_and_points',
      params: {
        'p_user_id': userId,
        'p_category': category,
        'p_action': action,
        'p_points': points,
        'p_description': description,
        'p_metadata': metadata,
      },
    );
  }
}

final pointsServiceProvider = Provider<PointsService>(
  (ref) => const PointsService(),
);
