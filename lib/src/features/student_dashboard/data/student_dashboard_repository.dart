import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_dashboard_models.dart';

class StudentDashboardRepository {
  StudentDashboardRepository(this._client);

  final SupabaseClient _client;

  Future<StudentDashboardVm> fetchDashboard({required String userId}) async {
    // 1) Profile: name + points (+ department)
    final profileRows = await _client
        .from('profiles')
        .select('id, email, full_name, total_points, department')
        .eq('id', userId)
        .limit(1);

    final profile = profileRows.isNotEmpty ? profileRows.first : <String, dynamic>{};

    final fullName = (profile['full_name'] as String?)?.trim();
    final email = (profile['email'] as String?)?.trim();

    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (email != null && email.contains('@'))
            ? email.split('@').first
            : 'Öğrenci';

    final totalPoints = (profile['total_points'] as int?) ?? 0;

    // 2) Completed courses count
    final completedRows = await _client
        .from('completed_courses')
        .select('id')
        .eq('id', userId);

    final coursesCompleted = completedRows.length;

    // 3) Ongoing courses count + list (progress < 100)
    final ongoingEnrollRows = await _client
        .from('course_enrollments')
        .select('course_id, progress, enrolled_at')
        .eq('id', userId)
        .lt('progress', 100)
        .order('enrolled_at', ascending: false);

    final ongoingCoursesCount = ongoingEnrollRows.length;

    // take top 3 for the dashboard card
    final ongoingTop = ongoingEnrollRows.take(3).toList();
    final courseIds = ongoingTop
        .map((e) => (e['course_id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    Map<String, Map<String, dynamic>> courseById = {};
    if (courseIds.isNotEmpty) {
      final courseRows = await _client
          .from('courses')
          .select('id, title, description, duration, level')
          .inFilter('id', courseIds);

      courseById = {
        for (final r in courseRows)
          // ignore: unnecessary_cast
          (r['id'] as String): (r as Map<String, dynamic>),
      };
    }

    final enrolledCourses = <EnrolledCourse>[
      for (final enr in ongoingTop)
        () {
          final cid = (enr['course_id'] as String?) ?? '';
          final c = courseById[cid] ?? const <String, dynamic>{};

          final title = (c['title'] as String?) ?? 'Kurs';
          final description = (c['description'] as String?) ?? '';
          final duration = (c['duration'] as String?) ?? '';
          final level = (c['level'] as String?) ?? '';

          final progress = (enr['progress'] as int?) ?? 0;

          return EnrolledCourse(
            courseId: cid,
            title: title,
            description: description,
            duration: duration,
            level: level,
            progress: progress.clamp(0, 100),
          );
        }(),
    ];

    // 4) Active applications count (pending)
    final jobPending = await _client
        .from('job_applications')
        .select('id')
        .eq('id', userId)
        .eq('status', 'pending');

    final internshipPending = await _client
        .from('internship_applications')
        .select('id')
        .eq('id', userId)
        .eq('status', 'pending');

    final activeApplications = jobPending.length + internshipPending.length;

    // 5) Department rank (optional): latest snapshot for user
    int? departmentRank;
    final lb = await _client
        .from('leaderboard_snapshots')
        .select('rank_department, created_at')
        .eq('id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (lb.isNotEmpty) {
      departmentRank = (lb.first['rank_department'] as int?);
    }

    // 6) Activities (from activity_logs)
    final activityRows = await _client
        .from('activity_logs')
        .select('category, action, points, created_at')
        .eq('id', userId)
        .order('created_at', ascending: false)
        .limit(6);

    final activities = <ActivityItem>[
      for (final r in activityRows)
        ActivityItem(
          category: _mapCategory((r['category'] as String?) ?? ''),
          action: (r['action'] as String?) ?? '',
          points: (r['points'] as int?) ?? 0,
          createdAt: DateTime.tryParse((r['created_at'] as String?) ?? '')?.toLocal() ??
              DateTime.now(),
        ),
    ];

    // 7) Today + week points (sum activity_logs.points)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1)); // Monday

    final todayRows = await _client
        .from('activity_logs')
        .select('points, created_at')
        .eq('id', userId)
        .gte('created_at', startOfDay.toUtc().toIso8601String());

    final weekRows = await _client
        .from('activity_logs')
        .select('points, created_at')
        .eq('id', userId)
        .gte('created_at', startOfWeek.toUtc().toIso8601String());

    final todayPoints = todayRows.fold<int>(0, (sum, r) => sum + ((r['points'] as int?) ?? 0));
    final weekPoints = weekRows.fold<int>(0, (sum, r) => sum + ((r['points'] as int?) ?? 0));

    final stats = DashboardStats(
      totalPoints: totalPoints,
      coursesCompleted: coursesCompleted,
      activeApplications: activeApplications,
      ongoingCourses: ongoingCoursesCount,
      departmentRank: departmentRank,
    );

    return StudentDashboardVm(
      displayName: displayName,
      stats: stats,
      enrolledCourses: enrolledCourses,
      activities: activities,
      todayPoints: todayPoints,
      weekPoints: weekPoints,
    );
  }

  static ActivityCategory _mapCategory(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'course':
        return ActivityCategory.course;
      case 'job':
        return ActivityCategory.job;
      case 'internship':
        return ActivityCategory.internship;
      case 'achievement':
        return ActivityCategory.achievement;
      case 'platform':
        return ActivityCategory.platform;
      default:
        return ActivityCategory.platform;
    }
  }
}
