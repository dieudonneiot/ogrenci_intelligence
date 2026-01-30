
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/dashboard_application.dart';

typedef Json = Map<String, dynamic>;

Json _asJson(dynamic v) {
  if (v is Json) return v;
  if (v is Map) return v.cast<String, dynamic>();
  throw StateError('Expected Map<String,dynamic> but got ${v.runtimeType}');
}

List<Json> _asJsonList(dynamic v) {
  if (v is List) {
    return v
        .where((e) => e != null)
        .map((e) => _asJson(e))
        .toList(growable: false);
  }
  return const <Json>[];
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _asString(dynamic v, {String fallback = ''}) {
  if (v is String) return v;
  return v?.toString() ?? fallback;
}

DateTime? _asDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class StudentDashboardRepository {
  const StudentDashboardRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<StudentDashboardData> fetchDashboard({
    required String userId,
    required String email,
    required String fallbackFullName,
  }) async {
    final profile = await _fetchProfile(
      userId: userId,
      email: email,
      fallbackFullName: fallbackFullName,
    );

    final completedCourses = await _fetchCompletedCoursesCount(userId);
    final activeApplications = await _fetchActiveApplicationsCount(userId);

    final enrolledCourses = await _fetchEnrolledCourses(userId);
    final activities = await _fetchRecentActivities(userId);

    return StudentDashboardData(
      profile: profile,
      completedCourses: completedCourses,
      activeApplications: activeApplications,
      enrolledCourses: enrolledCourses,
      recentActivities: activities,
    );
  }

  Future<StudentProfile> _fetchProfile({
    required String userId,
    required String email,
    required String fallbackFullName,
  }) async {
    // profiles: id, full_name, department, year, total_points, email
    final dynamic res = await _client
        .from('profiles')
        .select('id, full_name, department, year, total_points')
        .eq('id', userId)
        .maybeSingle();

    final Json? row = (res == null) ? null : _asJson(res);

    final fullName = _asString(row?['full_name']).trim();
    final department = _asString(row?['department']).trim();
    final year = _asInt(row?['year'], fallback: 1);
    final points = _asInt(row?['total_points'], fallback: 0);

    return StudentProfile(
      userId: userId,
      email: email,
      fullName: fullName.isNotEmpty ? fullName : fallbackFullName,
      department: department.isNotEmpty ? department : '—',
      year: year,
      totalPoints: points,
    );
  }

  Future<int> _fetchCompletedCoursesCount(String userId) async {
    // completed_courses: id, user_id
    final dynamic res = await _client
        .from('completed_courses')
        .select('id')
        .eq('user_id', userId);

    return _asJsonList(res).length;
  }

  Future<int> _fetchActiveApplicationsCount(String userId) async {
    // job_applications: user_id, status
    // internship_applications: user_id, status
    final dynamic jobs = await _client
        .from('job_applications')
        .select('id, status')
        .eq('user_id', userId)
        .eq('status', 'pending');

    final dynamic internships = await _client
        .from('internship_applications')
        .select('id, status')
        .eq('user_id', userId)
        .eq('status', 'pending');

    return _asJsonList(jobs).length + _asJsonList(internships).length;
  }

  Future<List<EnrolledCourse>> _fetchEnrolledCourses(String userId) async {
    // course_enrollments: id, user_id, progress, enrolled_at, course_id
    // courses: id, title, description, duration, level
    final dynamic res = await _client
        .from('course_enrollments')
        .select('id, progress, enrolled_at, courses(id, title, description, duration, level)')
        .eq('user_id', userId)
        .order('enrolled_at', ascending: false);

    final rows = _asJsonList(res);

    return rows.map((r) {
      final enrollmentId = _asString(r['id']);
      final progress = _asInt(r['progress'], fallback: 0).clamp(0, 100);

      final Json course = r['courses'] == null ? const <String, dynamic>{} : _asJson(r['courses']);
      final courseId = _asString(course['id']);
      final title = _asString(course['title']);
      final description = _asString(course['description']);
      final duration = _asString(course['duration'], fallback: '—');
      final level = _asString(course['level'], fallback: '—');

      return EnrolledCourse(
        enrollmentId: enrollmentId,
        courseId: courseId,
        title: title.isNotEmpty ? title : 'Untitled course',
        description: description,
        duration: duration,
        level: level,
        progress: progress,
        enrolledAt: _asDate(r['enrolled_at']),
      );
    }).toList(growable: false);
  }

  Future<List<ActivityItem>> _fetchRecentActivities(String userId) async {
    // activity_logs: user_id, type, points, created_at, description
    final dynamic res = await _client
        .from('activity_logs')
        .select('type, points, created_at, description')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(10);

    final rows = _asJsonList(res);

    return rows.map((r) {
      return ActivityItem(
        type: _asString(r['type']),
        points: _asInt(r['points'], fallback: 0),
        createdAt: _asDate(r['created_at']),
        description: _asString(r['description'], fallback: ''),
      );
    }).toList(growable: false);
  }
}
