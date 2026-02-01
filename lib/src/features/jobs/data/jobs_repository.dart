import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/job_models.dart';

class JobsRepository {
  JobsRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  String _safeLike(String input) {
    // prevent wildcard injection (%, _) and commas breaking PostgREST "or()" syntax
    return input.replaceAll('%', '').replaceAll('_', '').replaceAll(',', ' ').trim();
  }

  Future<List<JobSummary>> fetchJobs({
    required JobFilters filters,
    int limit = 80,
  }) async {
    var q = _client
        .from('jobs')
        .select(
          'id,title,company,department,location,work_type,type,is_remote,is_active,created_at,deadline,salary,application_count',
        )
        .eq('is_active', true);

    // Hide expired (keep null deadlines)
    final nowIso = DateTime.now().toUtc().toIso8601String();
    q = q.or('deadline.is.null,deadline.gte.$nowIso');

    final dept = (filters.department ?? '').trim();
    if (dept.isNotEmpty) {
      q = q.eq('department', dept);
    }

    final wt = (filters.workType ?? '').trim();
    if (wt.isNotEmpty) {
      q = q.eq('work_type', wt);
    }

    if (filters.remoteOnly) {
      q = q.eq('is_remote', true);
    }

    final query = _safeLike(filters.query);
    if (query.isNotEmpty) {
      // PostgREST OR across multiple columns
      final pat = '%$query%';
      q = q.or(
        'title.ilike.$pat,company.ilike.$pat,department.ilike.$pat,location.ilike.$pat',
      );
    }

    final rows = await q
        .order('deadline', ascending: true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => JobSummary.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Job>> fetchJobsRaw({
    required JobsFilters filters,
    int limit = 80,
  }) async {
    var q = _client
        .from('jobs')
        .select(
          'id, company_id, company, title, department, location, description, requirements, '
          'salary_min, salary_max, type, is_remote, work_type, deadline, is_active, min_year, max_year, created_at',
        )
        .eq('is_active', true);

    // Hide expired (keep null deadlines)
    final nowIso = DateTime.now().toUtc().toIso8601String();
    q = q.or('deadline.is.null,deadline.gte.$nowIso');

    final search = _safeLike(filters.query);
    if (search.isNotEmpty) {
      q = q.or(
        'title.ilike.%$search%,company.ilike.%$search%,department.ilike.%$search%,location.ilike.%$search%',
      );
    }

    final dept = (filters.department ?? '').trim();
    if (dept.isNotEmpty) {
      q = q.eq('department', dept);
    }
    final wt = (filters.workType ?? '').trim();
    if (wt.isNotEmpty) {
      q = q.eq('work_type', wt);
    }
    if (filters.remoteOnly) {
      q = q.eq('is_remote', true);
    }

    final rows = await q
        .order('deadline', ascending: true)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => Job.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<JobDetail> fetchJobById({required String jobId}) async {
    final row = await _client
        .from('jobs')
        .select(
          'id,title,company,department,location,work_type,type,is_remote,is_active,created_at,deadline,salary,application_count,'
          'description,requirements,benefits,contact_email,min_year,max_year,views_count,company_id,created_by',
        )
        .eq('id', jobId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Job not found: $jobId');
    }
    return JobDetail.fromMap(row);
  }

  Future<Job?> fetchJobByIdRaw({required String jobId}) async {
    final row = await _client
        .from('jobs')
        .select(
          'id, company_id, company, title, department, location, description, requirements, '
          'salary_min, salary_max, type, is_remote, work_type, deadline, is_active, min_year, max_year, created_at',
        )
        .eq('id', jobId)
        .maybeSingle();

    if (row == null) return null;
    return Job.fromMap(row);
  }

  Future<Set<String>> fetchMyFavoriteJobIds({required String userId}) async {
    final rows = await _client
        .from('favorites')
        .select('job_id')
        .eq('user_id', userId)
        .eq('type', 'job');

    final set = <String>{};
    for (final r in (rows as List)) {
      final m = r as Map<String, dynamic>;
      final jid = m['job_id']?.toString();
      if (jid != null && jid.isNotEmpty) set.add(jid);
    }
    return set;
  }

  Future<void> addJobFavorite({
    required String userId,
    required String jobId,
  }) async {
    await _client.from('favorites').insert({
      'user_id': userId,
      'type': 'job',
      'job_id': jobId,
    });
  }

  Future<void> removeJobFavorite({
    required String userId,
    required String jobId,
  }) async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('type', 'job')
        .eq('job_id', jobId);
  }

  Future<bool> isJobFavorited({required String userId, required String jobId}) async {
    final row = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('job_id', jobId)
        .eq('type', 'job')
        .maybeSingle();
    return row != null;
  }

  Future<bool> toggleFavorite({required String userId, required String jobId}) async {
    final exists = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('job_id', jobId)
        .eq('type', 'job')
        .maybeSingle();

    if (exists != null) {
      await _client.from('favorites').delete().eq('id', exists['id']);
      return false;
    }

    await _client.from('favorites').insert({
      'user_id': userId,
      'job_id': jobId,
      'type': 'job',
    });
    return true;
  }

  Future<bool> hasApplied({required String userId, required String jobId}) async {
    final row = await _client
        .from('job_applications')
        .select('id,status')
        .eq('user_id', userId)
        .eq('job_id', jobId)
        .maybeSingle();

    return row != null;
  }

  Future<Map<String, String>> fetchMyJobApplicationStatuses({
    required String userId,
  }) async {
    final rows = await _client
        .from('job_applications')
        .select('job_id, status')
        .eq('user_id', userId);

    final map = <String, String>{};
    for (final r in (rows as List)) {
      final m = r as Map<String, dynamic>;
      final jid = m['job_id']?.toString();
      if (jid == null || jid.isEmpty) continue;
      map[jid] = (m['status'] ?? 'pending').toString();
    }
    return map;
  }

  Future<String?> fetchMyJobApplicationStatusForJob({
    required String userId,
    required String jobId,
  }) async {
    final row = await _client
        .from('job_applications')
        .select('status')
        .eq('user_id', userId)
        .eq('job_id', jobId)
        .maybeSingle();

    return row == null ? null : (row['status'] ?? 'pending').toString();
  }

  Future<void> applyToJob({
    required String userId,
    required String jobId,
    String? coverLetter,
    String? cvUrl,
  }) async {
    // prevent duplicate apply
    final already = await hasApplied(userId: userId, jobId: jobId);
    if (already) return;

    await _client.from('job_applications').insert({
      'user_id': userId,
      'job_id': jobId,
      'cover_letter': (coverLetter?.trim().isEmpty ?? true) ? null : coverLetter!.trim(),
      'cv_url': (cvUrl?.trim().isEmpty ?? true) ? null : cvUrl!.trim(),
      'status': 'pending',
    });
  }

  Future<void> logView({String? userId, required String jobId}) async {
    // optional analytics table
    await _client.from('job_views').insert({
      'job_id': jobId,
      'user_id': (userId?.isEmpty ?? true) ? null : userId,
    });
  }
}
