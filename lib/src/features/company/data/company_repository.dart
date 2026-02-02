import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/company_models.dart';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

class CompanyRepository {
  CompanyRepository(this._client);

  final SupabaseClient _client;

  /// Returns membership if the current user belongs to a company.
  /// Mirrors React: supabase.from("company_users").select("company_id, role").eq("user_id", user.id).maybeSingle()
  Future<({String companyId, String role})?> getMembershipByUserId(String userId) async {
    final row = await _client
        .from('company_users')
        .select('company_id, role')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;

    return (
      companyId: row['company_id'].toString(),
      role: (row['role'] ?? '').toString(),
    );
  }

  /// Optional: get company basic profile (we'll expand later based on your DB schema).
  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    final row = await _client
        .from('companies')
        .select('*')
        .eq('id', companyId)
        .maybeSingle();
    return row;
  }

  Future<void> updateCompany(String companyId, Map<String, dynamic> updates) async {
    await _client.from('companies').update(updates).eq('id', companyId);
  }

  Future<CompanyStatus> fetchCompanyStatus({required String companyId}) async {
    final row = await _client
        .from('companies')
        .select('approval_status, rejection_reason, banned_at, company_subscriptions(is_active, ends_at)')
        .eq('id', companyId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Company not found.');
    }

    final subs = (row['company_subscriptions'] as List?)?.cast<dynamic>() ?? const [];
    final now = DateTime.now();
    bool hasActiveSubscription = false;

    for (final entry in subs) {
      final map = Map<String, dynamic>.from(entry as Map);
      if (map['is_active'] != true) continue;
      final endsAt = _asDate(map['ends_at']);
      if (endsAt != null && endsAt.isBefore(now)) continue;
      hasActiveSubscription = true;
      break;
    }

    return CompanyStatus(
      approvalStatus: (row['approval_status'] ?? 'pending').toString(),
      rejectionReason: (row['rejection_reason'] as String?)?.trim(),
      isBanned: row['banned_at'] != null,
      hasActiveSubscription: hasActiveSubscription,
    );
  }

  Future<CompanyStats> fetchStats({required String companyId}) async {
    // Jobs
    final jobs = await _client
        .from('jobs')
        .select('id, is_active')
        .eq('company_id', companyId);

    final jobRows = (jobs as List).cast<dynamic>();
    final jobIds = jobRows.map((e) => (e as Map<String, dynamic>)['id']?.toString()).whereType<String>().toList();
    final activeJobs = jobRows.where((e) => (e as Map<String, dynamic>)['is_active'] == true).length;

    // Internships
    final internships = await _client
        .from('internships')
        .select('id, is_active')
        .eq('company_id', companyId);

    final internshipRows = (internships as List).cast<dynamic>();
    final internshipIds = internshipRows
        .map((e) => (e as Map<String, dynamic>)['id']?.toString())
        .whereType<String>()
        .toList();
    final activeInternships =
        internshipRows.where((e) => (e as Map<String, dynamic>)['is_active'] == true).length;

    int totalApplications = 0;
    int pendingApplications = 0;

    if (jobIds.isNotEmpty) {
      final jobApps = await _client
          .from('job_applications')
          .select('status')
          .inFilter('job_id', jobIds);
      final jobAppRows = (jobApps as List).cast<dynamic>();
      totalApplications += jobAppRows.length;
      pendingApplications += jobAppRows.where((e) => (e as Map<String, dynamic>)['status'] == 'pending').length;
    }

    if (internshipIds.isNotEmpty) {
      final internshipApps = await _client
          .from('internship_applications')
          .select('status')
          .inFilter('internship_id', internshipIds);
      final internshipAppRows = (internshipApps as List).cast<dynamic>();
      totalApplications += internshipAppRows.length;
      pendingApplications +=
          internshipAppRows.where((e) => (e as Map<String, dynamic>)['status'] == 'pending').length;
    }

    return CompanyStats(
      totalJobs: jobRows.length,
      activeJobs: activeJobs,
      totalApplications: totalApplications,
      pendingApplications: pendingApplications,
      totalInternships: internshipRows.length,
      activeInternships: activeInternships,
    );
  }

  Future<CompanyReportSummary> fetchReportSummary({
    required String companyId,
    DateTime? startDate,
  }) async {
    final params = {
      'p_company_id': companyId,
      if (startDate != null) 'p_start_date': startDate.toIso8601String().substring(0, 10),
    };

    try {
      final result = await _client.rpc('get_company_report_summary', params: params);
      final row = result is List
          ? (result.isNotEmpty ? result.first as Map<String, dynamic> : null)
          : (result as Map<String, dynamic>?);
      if (row != null) {
        return CompanyReportSummary.fromMetrics(row);
      }
    } catch (_) {
      // Fallback: keep app functional if RPC is not installed yet.
    }

    // Fallback to existing metrics table (if any) without RPC.
    final metrics = await _client
        .from('company_metrics')
        .select(
          'total_views, unique_visitors, total_applications, accepted_applications, '
          'rejected_applications, avg_response_time_hours, conversion_rate, active_jobs, active_internships',
        )
        .eq('company_id', companyId)
        .order('metric_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (metrics != null) {
      return CompanyReportSummary.fromMetrics(metrics);
    }

    return CompanyReportSummary.empty();
  }

  Future<CompanyReportTrends> fetchReportTrends({
    required String companyId,
    int days = 7,
    DateTime? startDate,
  }) async {
    final trendParams = {
      'p_company_id': companyId,
      'p_days': days,
      if (startDate != null) 'p_start_date': startDate.toIso8601String().substring(0, 10),
    };

    try {
      final trendRows = await _client.rpc('get_company_report_trends', params: trendParams);
      final trendsList = (trendRows as List?)?.cast<dynamic>() ?? const [];
      final views = <CompanyTrendPoint>[];
      final applications = <CompanyTrendPoint>[];
      for (final entry in trendsList) {
        final row = Map<String, dynamic>.from(entry as Map);
        final date = _asDate(row['metric_date']);
        if (date == null) continue;
        views.add(CompanyTrendPoint(date: date, count: _asInt(row['views'])));
        applications.add(CompanyTrendPoint(date: date, count: _asInt(row['applications'])));
      }

      final deptRows = await _client.rpc(
        'get_company_report_departments',
        params: {
          'p_company_id': companyId,
          if (startDate != null) 'p_start_date': startDate.toIso8601String().substring(0, 10),
        },
      );
      final departmentCounts = <String, int>{};
      final deptList = (deptRows as List?)?.cast<dynamic>() ?? const [];
      for (final entry in deptList) {
        final row = Map<String, dynamic>.from(entry as Map);
        final dept = (row['department'] ?? 'Diğer').toString();
        final count = _asInt(row['applications']);
        departmentCounts[dept] = count;
      }

      final funnelRows = await _client.rpc(
        'get_company_report_funnel',
        params: {
          'p_company_id': companyId,
          if (startDate != null) 'p_start_date': startDate.toIso8601String().substring(0, 10),
        },
      );
      CompanyFunnel funnel = CompanyFunnel.empty();
      if (funnelRows is List && funnelRows.isNotEmpty) {
        final row = Map<String, dynamic>.from(funnelRows.first as Map);
        funnel = CompanyFunnel(
          views: _asInt(row['views']),
          applications: _asInt(row['applications']),
          accepted: _asInt(row['accepted']),
        );
      }

      return CompanyReportTrends(
        views: views,
        applications: applications,
        departmentCounts: departmentCounts,
        funnel: funnel,
      );
    } catch (_) {
      // Fallback when RPCs are not yet installed.
    }

    return CompanyReportTrends.empty();
  }

  Future<List<CompanyJobItem>> listJobs({
    required String companyId,
    bool? isActive,
  }) async {
    var query = _client
        .from('jobs')
        .select('id,title,department,location,is_active,created_at,deadline,views_count,job_applications(status)')
        .eq('company_id', companyId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => CompanyJobItem.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> getJobById({
    required String jobId,
    String? companyId,
  }) async {
    var query = _client.from('jobs').select('*').eq('id', jobId);
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    return await query.maybeSingle();
  }

  Future<void> createJob(Map<String, dynamic> payload) async {
    await _client.from('jobs').insert(payload);
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    await _client.from('jobs').update(updates).eq('id', jobId);
  }

  Future<void> setJobActive(String jobId, bool isActive) async {
    await _client.from('jobs').update({'is_active': isActive}).eq('id', jobId);
  }

  Future<List<CompanyApplication>> listJobApplications({
    required String jobId,
  }) async {
    final rows = await _client
        .from('job_applications')
        .select(
          'id, status, applied_at, created_at, cover_letter, cv_url, job_id, '
          'profile:profiles(id, full_name, email, phone, department, year)',
        )
        .eq('job_id', jobId)
        .order('applied_at', ascending: false);

    return (rows as List)
        .map((e) => CompanyApplication.fromJobMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> updateJobApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    await _client
        .from('job_applications')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', applicationId);
  }

  Future<List<CompanyInternshipItem>> listInternships({
    required String companyId,
    bool? isActive,
  }) async {
    var query = _client
        .from('internships')
        .select('id,title,department,location,is_active,created_at,deadline,internship_applications(status)')
        .eq('company_id', companyId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => CompanyInternshipItem.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> getInternshipById({
    required String internshipId,
    String? companyId,
  }) async {
    var query = _client.from('internships').select('*').eq('id', internshipId);
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    return await query.maybeSingle();
  }

  Future<void> createInternship(Map<String, dynamic> payload) async {
    await _client.from('internships').insert(payload);
  }

  Future<void> updateInternship(String internshipId, Map<String, dynamic> updates) async {
    await _client.from('internships').update(updates).eq('id', internshipId);
  }

  Future<void> setInternshipActive(String internshipId, bool isActive) async {
    await _client.from('internships').update({'is_active': isActive}).eq('id', internshipId);
  }

  Future<List<CompanyApplication>> listInternshipApplications({
    required String internshipId,
  }) async {
    final rows = await _client
        .from('internship_applications')
        .select(
          'id, status, applied_at, created_at, motivation_letter, cv_url, internship_id, '
          'profile:profiles(id, full_name, email, phone, department, year)',
        )
        .eq('internship_id', internshipId)
        .order('applied_at', ascending: false);

    return (rows as List)
        .map((e) => CompanyApplication.fromInternshipMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> updateInternshipApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    await _client
        .from('internship_applications')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', applicationId);
  }

  Future<List<CompanyApplication>> listCompanyApplications({
    required String companyId,
  }) async {
    final jobs = await _client
        .from('jobs')
        .select('id')
        .eq('company_id', companyId);
    final jobIds = (jobs as List)
        .map((e) => (e as Map<String, dynamic>)['id']?.toString())
        .whereType<String>()
        .toList();

    final internships = await _client
        .from('internships')
        .select('id')
        .eq('company_id', companyId);
    final internshipIds = (internships as List)
        .map((e) => (e as Map<String, dynamic>)['id']?.toString())
        .whereType<String>()
        .toList();

    final applications = <CompanyApplication>[];

    if (jobIds.isNotEmpty) {
      final jobApps = await _client
          .from('job_applications')
          .select(
            'id, status, applied_at, created_at, cover_letter, cv_url, job_id, '
            'profile:profiles(id, full_name, email, phone, department, year), '
            'job:jobs(id, title, department, location)',
          )
          .inFilter('job_id', jobIds)
          .order('applied_at', ascending: false);
      applications.addAll((jobApps as List)
          .map((e) => CompanyApplication.fromJobMap(e as Map<String, dynamic>)));
    }

    if (internshipIds.isNotEmpty) {
      final internshipApps = await _client
          .from('internship_applications')
          .select(
            'id, status, applied_at, created_at, motivation_letter, cv_url, internship_id, '
            'profile:profiles(id, full_name, email, phone, department, year), '
            'internship:internships(id, title, department, location)',
          )
          .inFilter('internship_id', internshipIds)
          .order('applied_at', ascending: false);
      applications.addAll((internshipApps as List)
          .map((e) => CompanyApplication.fromInternshipMap(e as Map<String, dynamic>)));
    }

    applications.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return applications;
  }
}
