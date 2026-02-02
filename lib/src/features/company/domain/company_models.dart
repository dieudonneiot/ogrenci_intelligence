import 'package:flutter/foundation.dart';

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == 't' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == 'f' || s == '0' || s == 'no') return false;
  }
  return false;
}

String? _asTrimmedString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

@immutable
class CompanyStatus {
  const CompanyStatus({
    required this.approvalStatus,
    required this.rejectionReason,
    required this.isBanned,
    required this.hasActiveSubscription,
  });

  final String approvalStatus;
  final String? rejectionReason;
  final bool isBanned;
  final bool hasActiveSubscription;
}

@immutable
class CompanyStats {
  const CompanyStats({
    required this.totalJobs,
    required this.activeJobs,
    required this.totalApplications,
    required this.pendingApplications,
    required this.totalInternships,
    required this.activeInternships,
  });

  final int totalJobs;
  final int activeJobs;
  final int totalApplications;
  final int pendingApplications;
  final int totalInternships;
  final int activeInternships;

  factory CompanyStats.empty() => const CompanyStats(
        totalJobs: 0,
        activeJobs: 0,
        totalApplications: 0,
        pendingApplications: 0,
        totalInternships: 0,
        activeInternships: 0,
      );
}

@immutable
class CompanyReportSummary {
  const CompanyReportSummary({
    required this.totalViews,
    required this.uniqueVisitors,
    required this.totalApplications,
    required this.acceptedApplications,
    required this.rejectedApplications,
    required this.avgResponseTimeHours,
    required this.conversionRate,
    required this.activeJobs,
    required this.activeInternships,
  });

  final int totalViews;
  final int uniqueVisitors;
  final int totalApplications;
  final int acceptedApplications;
  final int rejectedApplications;
  final double avgResponseTimeHours;
  final double conversionRate;
  final int activeJobs;
  final int activeInternships;

  factory CompanyReportSummary.empty() => const CompanyReportSummary(
        totalViews: 0,
        uniqueVisitors: 0,
        totalApplications: 0,
        acceptedApplications: 0,
        rejectedApplications: 0,
        avgResponseTimeHours: 0,
        conversionRate: 0,
        activeJobs: 0,
        activeInternships: 0,
      );

  factory CompanyReportSummary.fromMetrics(Map<String, dynamic> map) {
    return CompanyReportSummary(
      totalViews: _asInt(map['total_views']),
      uniqueVisitors: _asInt(map['unique_visitors']),
      totalApplications: _asInt(map['total_applications']),
      acceptedApplications: _asInt(map['accepted_applications']),
      rejectedApplications: _asInt(map['rejected_applications']),
      avgResponseTimeHours: _asDouble(map['avg_response_time_hours']),
      conversionRate: _asDouble(map['conversion_rate']),
      activeJobs: _asInt(map['active_jobs']),
      activeInternships: _asInt(map['active_internships']),
    );
  }
}

@immutable
class CompanyTrendPoint {
  const CompanyTrendPoint({required this.date, required this.count});

  final DateTime date;
  final int count;
}

@immutable
class CompanyReportTrends {
  const CompanyReportTrends({
    required this.views,
    required this.applications,
    required this.departmentCounts,
    required this.funnel,
  });

  final List<CompanyTrendPoint> views;
  final List<CompanyTrendPoint> applications;
  final Map<String, int> departmentCounts;
  final CompanyFunnel funnel;

  factory CompanyReportTrends.empty() => CompanyReportTrends(
        views: const [],
        applications: const [],
        departmentCounts: const {},
        funnel: CompanyFunnel.empty(),
      );
}

@immutable
class CompanyFunnel {
  const CompanyFunnel({
    required this.views,
    required this.applications,
    required this.accepted,
  });

  final int views;
  final int applications;
  final int accepted;

  factory CompanyFunnel.empty() => const CompanyFunnel(
        views: 0,
        applications: 0,
        accepted: 0,
      );
}

@immutable
class CompanyJobItem {
  const CompanyJobItem({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.isActive,
    required this.createdAt,
    required this.deadline,
    required this.applicationsCount,
    required this.acceptedCount,
    required this.viewsCount,
  });

  final String id;
  final String title;
  final String? department;
  final String? location;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? deadline;
  final int applicationsCount;
  final int acceptedCount;
  final int viewsCount;

  factory CompanyJobItem.fromMap(Map<String, dynamic> map) {
    final apps = (map['job_applications'] as List?)?.cast<dynamic>() ?? const [];
    final accepted = apps.where((a) => (a as Map<String, dynamic>)['status'] == 'accepted').length;
    return CompanyJobItem(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      department: _asTrimmedString(map['department']),
      location: _asTrimmedString(map['location']),
      isActive: _asBool(map['is_active']),
      createdAt: _asDate(map['created_at']) ?? DateTime.now(),
      deadline: _asDate(map['deadline']),
      applicationsCount: apps.length,
      acceptedCount: accepted,
      viewsCount: _asInt(map['views_count']),
    );
  }
}

@immutable
class CompanyInternshipItem {
  const CompanyInternshipItem({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.isActive,
    required this.createdAt,
    required this.deadline,
    required this.applicationsCount,
    required this.acceptedCount,
  });

  final String id;
  final String title;
  final String? department;
  final String? location;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? deadline;
  final int applicationsCount;
  final int acceptedCount;

  factory CompanyInternshipItem.fromMap(Map<String, dynamic> map) {
    final apps = (map['internship_applications'] as List?)?.cast<dynamic>() ?? const [];
    final accepted = apps.where((a) => (a as Map<String, dynamic>)['status'] == 'accepted').length;
    return CompanyInternshipItem(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      department: _asTrimmedString(map['department']),
      location: _asTrimmedString(map['location']),
      isActive: _asBool(map['is_active']),
      createdAt: _asDate(map['created_at']) ?? DateTime.now(),
      deadline: _asDate(map['deadline']),
      applicationsCount: apps.length,
      acceptedCount: accepted,
    );
  }
}

@immutable
class CompanyApplication {
  const CompanyApplication({
    required this.id,
    required this.type,
    required this.status,
    required this.appliedAt,
    required this.profileName,
    required this.profileEmail,
    required this.profilePhone,
    required this.profileDepartment,
    required this.profileYear,
    required this.title,
    required this.department,
    required this.location,
    required this.coverLetter,
    required this.motivationLetter,
    required this.cvUrl,
    required this.jobId,
    required this.internshipId,
  });

  final String id;
  final String type; // job | internship
  final String status;
  final DateTime appliedAt;

  final String? profileName;
  final String? profileEmail;
  final String? profilePhone;
  final String? profileDepartment;
  final int? profileYear;

  final String? title;
  final String? department;
  final String? location;

  final String? coverLetter;
  final String? motivationLetter;
  final String? cvUrl;

  final String? jobId;
  final String? internshipId;

  factory CompanyApplication.fromJobMap(Map<String, dynamic> map) {
    final profile = (map['profile'] as Map<String, dynamic>?) ?? const {};
    final job = (map['job'] as Map<String, dynamic>?) ?? const {};
    return CompanyApplication(
      id: (map['id'] ?? '').toString(),
      type: 'job',
      status: (map['status'] ?? 'pending').toString(),
      appliedAt: _asDate(map['applied_at']) ?? _asDate(map['created_at']) ?? DateTime.now(),
      profileName: _asTrimmedString(profile['full_name']),
      profileEmail: _asTrimmedString(profile['email']),
      profilePhone: _asTrimmedString(profile['phone']),
      profileDepartment: _asTrimmedString(profile['department']),
      profileYear: profile['year'] == null ? null : _asInt(profile['year']),
      title: _asTrimmedString(job['title']),
      department: _asTrimmedString(job['department']),
      location: _asTrimmedString(job['location']),
      coverLetter: _asTrimmedString(map['cover_letter']),
      motivationLetter: null,
      cvUrl: _asTrimmedString(map['cv_url']),
      jobId: _asTrimmedString(map['job_id']),
      internshipId: null,
    );
  }

  factory CompanyApplication.fromInternshipMap(Map<String, dynamic> map) {
    final profile = (map['profile'] as Map<String, dynamic>?) ?? const {};
    final internship = (map['internship'] as Map<String, dynamic>?) ?? const {};
    return CompanyApplication(
      id: (map['id'] ?? '').toString(),
      type: 'internship',
      status: (map['status'] ?? 'pending').toString(),
      appliedAt: _asDate(map['applied_at']) ?? _asDate(map['created_at']) ?? DateTime.now(),
      profileName: _asTrimmedString(profile['full_name']),
      profileEmail: _asTrimmedString(profile['email']),
      profilePhone: _asTrimmedString(profile['phone']),
      profileDepartment: _asTrimmedString(profile['department']),
      profileYear: profile['year'] == null ? null : _asInt(profile['year']),
      title: _asTrimmedString(internship['title']),
      department: _asTrimmedString(internship['department']),
      location: _asTrimmedString(internship['location']),
      coverLetter: null,
      motivationLetter: _asTrimmedString(map['motivation_letter']),
      cvUrl: _asTrimmedString(map['cv_url']),
      jobId: null,
      internshipId: _asTrimmedString(map['internship_id']),
    );
  }
}

