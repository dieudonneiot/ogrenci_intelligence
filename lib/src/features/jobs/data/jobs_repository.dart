import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/job_models.dart';

class JobsRepository {
  JobsRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  String _safeLike(String input) {
    // prevent wildcard injection (%, _) in ilike/or filters
    return input.replaceAll('%', '').replaceAll('_', '').trim();
  }

  Future<List<JobSummary>> fetchJobs({
    required JobFilters filters,
    int limit = 60,
  }) async {
    var q = _client
        .from('jobs')
        .select(
          'id,title,company,department,location,work_type,type,is_remote,is_active,created_at,deadline,salary,application_count',
        )
        .eq('is_active', true);

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

    final rows = await q.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map((e) => JobSummary.fromMap(e as Map<String, dynamic>))
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
