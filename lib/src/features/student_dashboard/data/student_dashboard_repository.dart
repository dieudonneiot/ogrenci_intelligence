import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/student_dashboard_models.dart';

class StudentDashboardRepository {
  StudentDashboardRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<_ProfileInfo> getProfile(String uid) async {
    final rows = await _client
        .from('profiles')
        .select('id,full_name,department,total_points')
        .eq('id', uid)
        .limit(1) as List<dynamic>;

    if (rows.isEmpty) {
      return _ProfileInfo(uid: uid, fullName: null, department: null, totalPoints: 0);
    }

    final m = rows.first as Map<String, dynamic>;
    return _ProfileInfo(
      uid: uid,
      fullName: (m['full_name'] as String?)?.trim(),
      department: (m['department'] as String?)?.trim(),
      totalPoints: (m['total_points'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int?> getDepartmentRank({required String uid, required String? department}) async {
    final dept = department?.trim();
    if (dept == null || dept.isEmpty) return null;

    try {
      final row = await _client
          .from('department_leaderboard')
          .select('rank_in_department')
          .eq('user_id', uid)
          .eq('department', dept)
          .maybeSingle();

      if (row != null) {
        return (row['rank_in_department'] as num?)?.toInt();
      }
    } catch (_) {
      // fallback below
    }

    final rows = await _client
        .from('leaderboard_snapshots')
        .select('rank_department,period_date')
        .eq('user_id', uid)
        .eq('department', dept)
        .order('period_date', ascending: false)
        .limit(1) as List<dynamic>;

    if (rows.isEmpty) return null;
    final m = rows.first as Map<String, dynamic>;
    return (m['rank_department'] as num?)?.toInt();
  }

  Future<_Counts> getCounts(String uid) async {
    final completedRows = await _client
        .from('completed_courses')
        .select('id')
        .eq('user_id', uid) as List<dynamic>;

    final enrollRows = await _client
        .from('course_enrollments')
        .select('id,progress')
        .eq('user_id', uid) as List<dynamic>;

    final ongoing = enrollRows.where((e) {
      final m = e as Map<String, dynamic>;
      final p = (m['progress'] as num?)?.toInt() ?? 0;
      return p < 100;
    }).length;

    // ✅ FIX: pending applications are in job_applications / internship_applications
    // application_notes has NO status column.
    final jobPending = await _client
        .from('job_applications')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'pending') as List<dynamic>;

    final internshipPending = await _client
        .from('internship_applications')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'pending') as List<dynamic>;

    return _Counts(
      coursesCompleted: completedRows.length,
      ongoingCourses: ongoing,
      activeApplications: jobPending.length + internshipPending.length,
    );
  }

  Future<List<DashboardEnrolledCourse>> listOngoingCourses({
    required String uid,
    int limit = 3,
  }) async {
    final rows = await _client
        .from('course_enrollments')
        .select('progress,enrolled_at,courses(id,title,description,duration,level)')
        .eq('user_id', uid)
        .order('enrolled_at', ascending: false)
        .limit(limit) as List<dynamic>;

    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final p = (m['progress'] as num?)?.toInt() ?? 0;

      final c = (m['courses'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return DashboardEnrolledCourse(
        courseId: (c['id']?.toString() ?? ''),
        title: (c['title'] as String?) ?? 'Kurs',
        description: (c['description'] as String?) ?? 'Açıklama yok.',
        duration: (c['duration'] as String?) ?? '—',
        level: (c['level'] as String?) ?? '—',
        progress: p.clamp(0, 100),
      );
    }).toList();
  }

  Future<List<ActivityItem>> listActivities({
    required String uid,
    int limit = 10,
  }) async {
    final rows = await _client
        .from('activity_logs')
        .select('category,action,points,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit) as List<dynamic>;

    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final category = (m['category'] as String?)?.trim() ?? 'platform';
      final action = (m['action'] as String?)?.trim();
      final created = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();
      return ActivityItem(
        category: _mapCategory(category),
        action: (action == null || action.isEmpty) ? 'Aktivite' : action,
        points: (m['points'] as num?)?.toInt() ?? 0,
        createdAt: created,
      );
    }).toList();
  }

  Future<StudentDashboardViewModel> fetchDashboard({
    required String uid,
    String? fallbackName,
  }) async {
    final profile = await getProfile(uid);

    final countsF = getCounts(uid);
    final rankF = getDepartmentRank(uid: uid, department: profile.department);
    final ongoingCoursesF = listOngoingCourses(uid: uid, limit: 3);
    final activitiesF = listActivities(uid: uid, limit: 10);

    final counts = await countsF;
    final rank = await rankF;
    final ongoingCourses = await ongoingCoursesF;
    final activities = await activitiesF;
    final todayPts = _sumTodayPoints(activities);
    final weekPts = _sumWeekPoints(activities);

    final displayFallback =
        (fallbackName == null || fallbackName.isEmpty) ? 'Öğrenci' : fallbackName;
    final displayName = (profile.fullName == null || profile.fullName!.isEmpty)
        ? displayFallback
        : profile.fullName!;

    return StudentDashboardViewModel(
      displayName: displayName,
      stats: StudentDashboardStats(
        totalPoints: profile.totalPoints,
        coursesCompleted: counts.coursesCompleted,
        activeApplications: counts.activeApplications,
        ongoingCourses: counts.ongoingCourses,
        departmentRank: rank,
      ),
      todayPoints: todayPts,
      weekPoints: weekPts,
      enrolledCourses: ongoingCourses,
      activities: activities,
    );
  }

  static int _sumTodayPoints(List<ActivityItem> activities) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var sum = 0;

    for (final a in activities) {
      final local = a.createdAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      if (d == today) sum += a.points;
    }

    return sum;
  }

  static int _sumWeekPoints(List<ActivityItem> activities) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    var sum = 0;

    for (final a in activities) {
      final local = a.createdAt.toLocal();
      if (!local.isBefore(weekAgo)) sum += a.points;
    }

    return sum;
  }

  static ActivityCategory _mapCategory(String category) {
    final t = category.toLowerCase();
    if (t.contains('course')) return ActivityCategory.course;
    if (t.contains('job')) return ActivityCategory.job;
    if (t.contains('intern')) return ActivityCategory.internship;
    if (t.contains('badge') || t.contains('achievement')) return ActivityCategory.achievement;
    return ActivityCategory.platform;
  }
}

class _ProfileInfo {
  const _ProfileInfo({
    required this.uid,
    required this.fullName,
    required this.department,
    required this.totalPoints,
  });

  final String uid;
  final String? fullName;
  final String? department;
  final int totalPoints;
}

class _Counts {
  const _Counts({
    required this.coursesCompleted,
    required this.activeApplications,
    required this.ongoingCourses,
  });

  final int coursesCompleted;
  final int activeApplications;
  final int ongoingCourses;
}
