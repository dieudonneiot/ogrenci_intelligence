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

  Future<int?> getLatestDepartmentRank(String uid) async {
    final rows = await _client
        .from('leaderboard_snapshots')
        .select('rank_department,period_date') // ✅ period_date exists
        .eq('user_id', uid)
        .order('period_date', ascending: false) // ✅ order by existing column
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

  Future<int> sumPointsSince(String uid, DateTime fromUtc) async {
    final rows = await _client
        .from('user_points')
        .select('points,created_at')
        .eq('user_id', uid)
        .gte('created_at', fromUtc.toIso8601String())
        .order('created_at', ascending: false) as List<dynamic>;

    var sum = 0;
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      sum += (m['points'] as num?)?.toInt() ?? 0;
    }
    return sum;
  }

  Future<List<DashboardEnrolledCourse>> listOngoingCourses({
    required String uid,
    int limit = 3,
  }) async {
    final rows = await _client
        .from('course_enrollments')
        .select('progress,enrolled_at,courses(id,title,description,duration,level)')
        .eq('user_id', uid)
        .lt('progress', 100)
        .order('enrolled_at', ascending: false)
        .limit(limit) as List<dynamic>;

    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final p = (m['progress'] as num?)?.toInt() ?? 0;

      final c = (m['courses'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return DashboardEnrolledCourse(
        courseId: (c['id']?.toString() ?? ''),
        title: (c['title'] as String?) ?? 'Course',
        description: (c['description'] as String?) ?? 'Açıklama yok.',
        duration: (c['duration'] as String?) ?? '—',
        level: (c['level'] as String?) ?? '—',
        progress: p.clamp(0, 100),
      );
    }).toList();
  }

  Future<List<ActivityItem>> listActivities({
    required String uid,
    int limit = 8,
  }) async {
    final List<ActivityItem> items = [];

    // 1) Points ledger
    final pointsRows = await _client
        .from('user_points')
        .select('points,event_type,description,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(10) as List<dynamic>;

    for (final r in pointsRows) {
      final m = r as Map<String, dynamic>;
      final pts = (m['points'] as num?)?.toInt() ?? 0;
      final type = (m['event_type'] as String?) ?? '';
      final desc = (m['description'] as String?) ?? 'Puan kazanıldı';
      final created = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();

      items.add(ActivityItem(
        category: _mapEventType(type),
        action: desc,
        points: pts,
        createdAt: created,
      ));
    }

    // 2) Course completions
    final completedRows = await _client
        .from('completed_courses')
        .select('created_at,courses(title)')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(5) as List<dynamic>;

    for (final r in completedRows) {
      final m = r as Map<String, dynamic>;
      final c = (m['courses'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final title = (c['title'] as String?) ?? 'Kurs';
      final created = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();

      items.add(ActivityItem(
        category: ActivityCategory.course,
        action: 'Kurs tamamlandı: $title',
        points: 0,
        createdAt: created,
      ));
    }

    // 3) Job applications
    final jobRows = await _client
        .from('job_applications')
        .select('created_at,status,jobs(title)')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(5) as List<dynamic>;

    for (final r in jobRows) {
      final m = r as Map<String, dynamic>;
      final j = (m['jobs'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final title = (j['title'] as String?) ?? 'İş';
      final created = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();

      items.add(ActivityItem(
        category: ActivityCategory.job,
        action: 'İş başvurusu: $title',
        points: 0,
        createdAt: created,
      ));
    }

    // 4) Internship applications
    final internRows = await _client
        .from('internship_applications')
        .select('created_at,status,internships(title)')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(5) as List<dynamic>;

    for (final r in internRows) {
      final m = r as Map<String, dynamic>;
      final it = (m['internships'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final title = (it['title'] as String?) ?? 'Staj';
      final created = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();

      items.add(ActivityItem(
        category: ActivityCategory.internship,
        action: 'Staj başvurusu: $title',
        points: 0,
        createdAt: created,
      ));
    }

    // 5) Badges
    final badgeRows = await _client
        .from('user_badges')
        .select('earned_at,badges(name)')
        .eq('user_id', uid)
        .order('earned_at', ascending: false)
        .limit(5) as List<dynamic>;

    for (final r in badgeRows) {
      final m = r as Map<String, dynamic>;
      final b = (m['badges'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final name = (b['name'] as String?) ?? 'Rozet';
      final created = DateTime.tryParse(m['earned_at']?.toString() ?? '') ?? DateTime.now();

      items.add(ActivityItem(
        category: ActivityCategory.achievement,
        action: 'Rozet kazanıldı: $name',
        points: 0,
        createdAt: created,
      ));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.length > limit) return items.take(limit).toList();
    return items;
  }

  Future<StudentDashboardViewModel> fetchDashboard({
    required String uid,
    String? fallbackName,
  }) async {
    final profile = await getProfile(uid);

    final now = DateTime.now().toUtc();
    final startToday = DateTime.utc(now.year, now.month, now.day);

    // Monday-based week start
    final startWeek = startToday.subtract(Duration(days: startToday.weekday - 1));

    final countsF = getCounts(uid);
    final rankF = getLatestDepartmentRank(uid);
    final todayF = sumPointsSince(uid, startToday);
    final weekF = sumPointsSince(uid, startWeek);
    final ongoingCoursesF = listOngoingCourses(uid: uid, limit: 3);
    final activitiesF = listActivities(uid: uid, limit: 8);

    final counts = await countsF;
    final rank = await rankF;
    final todayPts = await todayF;
    final weekPts = await weekF;
    final ongoingCourses = await ongoingCoursesF;
    final activities = await activitiesF;

    final displayFallback =
        (fallbackName == null || fallbackName.isEmpty) ? 'Ã–ÄŸrenci' : fallbackName;
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

  static ActivityCategory _mapEventType(String eventType) {
    final t = eventType.toLowerCase();
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
