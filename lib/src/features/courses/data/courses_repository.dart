import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/course_models.dart';

class CoursesRepository {
  CoursesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Course>> listCourses({
    String? search,
    String? department,
    String? level,
  }) async {
    PostgrestFilterBuilder qb = _client
        .from('courses')
        .select('id,title,description,department,video_url,duration,level,instructor');

    final q = (search ?? '').trim();
    if (q.isNotEmpty) {
      qb = qb.ilike('title', '%$q%');
    }
    if (department != null && department.trim().isNotEmpty) {
      qb = qb.eq('department', department.trim());
    }
    if (level != null && level.trim().isNotEmpty) {
      qb = qb.eq('level', level.trim());
    }

    final rows = await qb.order('title', ascending: true) as List<dynamic>;
    return rows
    .map((e) => Course.fromMap(Map<String, dynamic>.from(e as Map)))
    .toList();
  }

  Future<Course> getCourseById(String courseId) async {
    final row = await _client
        .from('courses')
        .select('id,title,description,department,video_url,duration,level,instructor')
        .eq('id', courseId)
        .single();

    return Course.fromMap(row);
  }

  Future<CourseEnrollment?> getMyEnrollment({
    required String userId,
    required String courseId,
  }) async {
    // Using .limit(1) to be version-safe (instead of maybeSingle()).
    final rows = await _client
        .from('course_enrollments')
        .select('id,user_id,course_id,enrolled_at,progress')
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .limit(1) as List<dynamic>;

    if (rows.isEmpty) return null;
    return CourseEnrollment.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<List<EnrolledCourse>> listMyEnrolledCourses(String userId) async {
    // FK exists: course_enrollments.course_id -> courses.id
    final rows = await _client
        .from('course_enrollments')
        .select(
          'id,user_id,course_id,enrolled_at,progress,'
          'courses(id,title,description,department,video_url,duration,level,instructor)',
        )
        .eq('user_id', userId)
        .order('enrolled_at', ascending: false) as List<dynamic>;

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final enrollment = CourseEnrollment.fromMap(map);

      final rawCourse = map['courses'];
final courseMap = rawCourse == null ? null : Map<String, dynamic>.from(rawCourse as Map);
      final course = courseMap == null
          ? Course(
              id: enrollment.courseId,
              title: 'Course',
            )
          : Course.fromMap(courseMap);

      return EnrolledCourse(course: course, enrollment: enrollment);
    }).toList();
  }

  Future<void> enroll({
    required String userId,
    required String courseId,
  }) async {
    await _client.from('course_enrollments').insert({
      'user_id': userId,
      'course_id': courseId,
      'progress': 0,
    });
  }

  Future<void> unenroll({
    required String userId,
    required String courseId,
  }) async {
    await _client
        .from('course_enrollments')
        .delete()
        .eq('user_id', userId)
        .eq('course_id', courseId);
  }

  Future<void> updateProgress({
    required String enrollmentId,
    required int progress,
  }) async {
    final p = progress.clamp(0, 100);
    await _client
        .from('course_enrollments')
        .update({'progress': p})
        .eq('id', enrollmentId);
  }
}
