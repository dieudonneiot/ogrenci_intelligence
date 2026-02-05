import '../../../core/supabase/supabase_service.dart';
import '../domain/applications_models.dart';

class ApplicationsRepository {
  const ApplicationsRepository();

  Future<List<ApplicationListItem>> fetchMyJobApplications({
    required String userId,
    int limit = 80,
  }) async {
    final rows = await SupabaseService.client
        .from('job_applications')
        .select(
          'id, job_id, status, applied_at, '
          'job:jobs(id, title, company, location)',
        )
        .eq('user_id', userId)
        .order('applied_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map(
          (e) => ApplicationListItem.fromJobApplicationMap(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<ApplicationListItem>> fetchMyInternshipApplications({
    required String userId,
    int limit = 80,
  }) async {
    final rows = await SupabaseService.client
        .from('internship_applications')
        .select(
          'id, internship_id, status, applied_at, motivation_letter, '
          'internship:internships(id, title, company_name, location)',
        )
        .eq('user_id', userId)
        .order('applied_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map(
          (e) => ApplicationListItem.fromInternshipApplicationMap(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<ApplicationListItem>> fetchMyCourseApplications({
    required String userId,
    int limit = 120,
  }) async {
    // enrollments
    final enrollRows = await SupabaseService.client
        .from('course_enrollments')
        .select(
          'id, course_id, enrolled_at, progress, '
          'course:courses(id, title)',
        )
        .eq('user_id', userId)
        .order('enrolled_at', ascending: false)
        .limit(limit);

    // completions
    final completedRows = await SupabaseService.client
        .from('completed_courses')
        .select('course_id, completed_at')
        .eq('user_id', userId);

    final completedAtByCourse = <String, DateTime>{};
    for (final r in (completedRows as List)) {
      final m = r as Map<String, dynamic>;
      final cid = (m['course_id'] ?? '').toString();
      if (cid.isEmpty) continue;
      completedAtByCourse[cid] =
          DateTime.tryParse((m['completed_at'] ?? '').toString()) ??
          DateTime.now();
    }

    return (enrollRows as List).map((e) {
      final m = e as Map<String, dynamic>;
      final cid = (m['course_id'] ?? '').toString();
      final completedAt = completedAtByCourse[cid];
      return ApplicationListItem.fromCourseEnrollmentMap(
        m,
        completedAt: completedAt,
      );
    }).toList();
  }
}
