import 'package:flutter/foundation.dart';

int _asInt(dynamic v) => (v is int) ? v : (v as num?)?.toInt() ?? 0;
bool _asBool(dynamic v) => (v is bool) ? v : (v as bool?) ?? false;

DateTime _asDate(dynamic v) {
  if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

@immutable
class JobSummary {
  const JobSummary({
    required this.id,
    required this.title,
    required this.company,
    required this.department,
    required this.location,
    required this.workType,
    required this.type,
    required this.isRemote,
    required this.isActive,
    required this.createdAt,
    required this.deadline,
    required this.salary,
    required this.applicationCount,
  });

  final String id;
  final String title;
  final String company;
  final String? department;
  final String? location;
  final String? workType; // jobs.work_type (text)
  final String? type; // jobs.type (departmental/part-time)
  final bool isRemote;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? deadline; // date
  final String? salary; // text
  final int applicationCount;

  factory JobSummary.fromMap(Map<String, dynamic> map) {
    return JobSummary(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      company: (map['company'] ?? '').toString(),
      department: (map['department'] as String?)?.trim(),
      location: (map['location'] as String?)?.trim(),
      workType: (map['work_type'] as String?)?.trim(),
      type: (map['type'] as String?)?.trim(),
      isRemote: _asBool(map['is_remote']),
      isActive: _asBool(map['is_active']),
      createdAt: _asDate(map['created_at']),
      deadline: map['deadline'] == null ? null : _asDate(map['deadline']),
      salary: (map['salary'] as String?)?.trim(),
      applicationCount: _asInt(map['application_count']),
    );
  }
}

@immutable
class JobDetail extends JobSummary {
  const JobDetail({
    required super.id,
    required super.title,
    required super.company,
    required super.department,
    required super.location,
    required super.workType,
    required super.type,
    required super.isRemote,
    required super.isActive,
    required super.createdAt,
    required super.deadline,
    required super.salary,
    required super.applicationCount,
    required this.description,
    required this.requirements,
    required this.benefits,
    required this.contactEmail,
    required this.minYear,
    required this.maxYear,
    required this.viewsCount,
    required this.companyId,
    required this.createdBy,
  });

  final String? description;
  final String? requirements;
  final String? benefits;
  final String? contactEmail;
  final int? minYear;
  final int? maxYear;
  final int viewsCount;
  final String? companyId;
  final String? createdBy;

  factory JobDetail.fromMap(Map<String, dynamic> map) {
    final base = JobSummary.fromMap(map);
    return JobDetail(
      id: base.id,
      title: base.title,
      company: base.company,
      department: base.department,
      location: base.location,
      workType: base.workType,
      type: base.type,
      isRemote: base.isRemote,
      isActive: base.isActive,
      createdAt: base.createdAt,
      deadline: base.deadline,
      salary: base.salary,
      applicationCount: base.applicationCount,
      description: (map['description'] as String?)?.trim(),
      requirements: (map['requirements'] as String?)?.trim(),
      benefits: (map['benefits'] as String?)?.trim(),
      contactEmail: (map['contact_email'] as String?)?.trim(),
      minYear: (map['min_year'] as int?),
      maxYear: (map['max_year'] as int?),
      viewsCount: _asInt(map['views_count']),
      companyId: (map['company_id'] as String?)?.trim(),
      createdBy: (map['created_by'] as String?)?.trim(),
    );
  }
}

@immutable
class JobFilters {
  const JobFilters({
    this.query = '',
    this.department,
    this.remoteOnly = false,
    this.workType,
  });

  final String query;
  final String? department;
  final bool remoteOnly;
  final String? workType;

  JobFilters copyWith({
    String? query,
    String? department,
    bool? remoteOnly,
    String? workType,
  }) {
    return JobFilters(
      query: query ?? this.query,
      department: department ?? this.department,
      remoteOnly: remoteOnly ?? this.remoteOnly,
      workType: workType ?? this.workType,
    );
  }

  bool get isDefault =>
      query.trim().isEmpty && department == null && remoteOnly == false && workType == null;
}

@immutable
class JobsListVm {
  const JobsListVm({
    required this.items,
    required this.favoriteJobIds,
  });

  final List<JobSummary> items;
  final Set<String> favoriteJobIds;

  JobsListVm copyWith({
    List<JobSummary>? items,
    Set<String>? favoriteJobIds,
  }) {
    return JobsListVm(
      items: items ?? this.items,
      favoriteJobIds: favoriteJobIds ?? this.favoriteJobIds,
    );
  }
}

@immutable
class JobDetailVm {
  const JobDetailVm({
    required this.job,
    required this.isFavorited,
    required this.hasApplied,
  });

  final JobDetail job;
  final bool isFavorited;
  final bool hasApplied;

  JobDetailVm copyWith({
    JobDetail? job,
    bool? isFavorited,
    bool? hasApplied,
  }) {
    return JobDetailVm(
      job: job ?? this.job,
      isFavorited: isFavorited ?? this.isFavorited,
      hasApplied: hasApplied ?? this.hasApplied,
    );
  }
}
