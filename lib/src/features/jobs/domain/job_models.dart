import 'package:flutter/foundation.dart';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
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

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

@immutable
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.companyId,
    required this.companyName,
    required this.department,
    required this.location,
    required this.description,
    required this.requirements,
    required this.type,
    required this.workType,
    required this.isRemote,
    required this.isActive,
    required this.compatibility,
    this.salaryMin,
    this.salaryMax,
    this.salaryText,
    this.deadline,
    this.minYear,
    this.maxYear,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String companyName;

  final String title;
  final String department;
  final String location;

  final String description;
  final String requirements;

  /// job type (in your schema: `type` text)
  final String type;

  /// work type (in your schema: `work_type` text)
  final String workType;

  final bool isRemote;
  final bool isActive;
  final int compatibility; // 0..100

  final int? salaryMin;
  final int? salaryMax;
  final String? salaryText;

  final DateTime? deadline;
  final int? minYear;
  final int? maxYear;

  final DateTime createdAt;

  Job copyWith({int? compatibility}) {
    return Job(
      id: id,
      title: title,
      companyId: companyId,
      companyName: companyName,
      department: department,
      location: location,
      description: description,
      requirements: requirements,
      type: type,
      workType: workType,
      isRemote: isRemote,
      isActive: isActive,
      compatibility: (compatibility ?? this.compatibility).clamp(0, 100),
      salaryMin: salaryMin,
      salaryMax: salaryMax,
      salaryText: salaryText,
      deadline: deadline,
      minYear: minYear,
      maxYear: maxYear,
      createdAt: createdAt,
    );
  }

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: (map['id'] ?? '').toString(),
      companyId: (map['company_id'] ?? '').toString(),
      companyName: (map['company_name'] ?? map['company'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      requirements: (map['requirements'] ?? '').toString(),
      salaryMin: map['salary_min'] == null ? null : _asInt(map['salary_min']),
      salaryMax: map['salary_max'] == null ? null : _asInt(map['salary_max']),
      salaryText: (map['salary'] ?? '').toString().trim().isEmpty
          ? null
          : (map['salary'] ?? '').toString().trim(),
      type: (map['type'] ?? '').toString(),
      isRemote: _asBool(map['is_remote']),
      workType: (map['work_type'] ?? '').toString(),
      deadline: _asDate(map['deadline']),
      isActive: _asBool(map['is_active']),
      minYear: map['min_year'] == null ? null : _asInt(map['min_year']),
      maxYear: map['max_year'] == null ? null : _asInt(map['max_year']),
      createdAt: _asDate(map['created_at']) ?? DateTime.now(),
      compatibility: 0,
    );
  }
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
      createdAt: _asDate(map['created_at']) ?? DateTime.now(),
      deadline: _asDate(map['deadline']),
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
      minYear: map['min_year'] == null ? null : _asInt(map['min_year']),
      maxYear: map['max_year'] == null ? null : _asInt(map['max_year']),
      viewsCount: _asInt(map['views_count']),
      companyId: (map['company_id'] as String?)?.trim(),
      createdBy: (map['created_by'] as String?)?.trim(),
    );
  }
}

@immutable
class JobsFilters {
  const JobsFilters({
    this.query = '',
    this.department,
    this.city,
    this.workType,
    this.remoteOnly = false,
  });

  final String query;
  final String? department;
  final String? city;
  final String? workType;
  final bool remoteOnly;

  JobsFilters copyWith({
    String? query,
    String? department,
    String? city,
    String? workType,
    bool? remoteOnly,
    bool clearDepartment = false,
    bool clearCity = false,
    bool clearWorkType = false,
  }) {
    return JobsFilters(
      query: query ?? this.query,
      department: clearDepartment ? null : (department ?? this.department),
      city: clearCity ? null : (city ?? this.city),
      workType: clearWorkType ? null : (workType ?? this.workType),
      remoteOnly: remoteOnly ?? this.remoteOnly,
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
    bool clearDepartment = false,
    bool clearWorkType = false,
  }) {
    return JobFilters(
      query: query ?? this.query,
      department: clearDepartment ? null : (department ?? this.department),
      remoteOnly: remoteOnly ?? this.remoteOnly,
      workType: clearWorkType ? null : (workType ?? this.workType),
    );
  }

  bool get isDefault =>
      query.trim().isEmpty &&
      department == null &&
      remoteOnly == false &&
      workType == null;
}

@immutable
class JobsListVm {
  const JobsListVm({required this.items, required this.favoriteJobIds});

  final List<JobSummary> items;
  final Set<String> favoriteJobIds;

  JobsListVm copyWith({List<JobSummary>? items, Set<String>? favoriteJobIds}) {
    return JobsListVm(
      items: items ?? this.items,
      favoriteJobIds: favoriteJobIds ?? this.favoriteJobIds,
    );
  }
}

@immutable
class JobCardVM {
  const JobCardVM({
    required this.job,
    required this.isFavorite,
    required this.applicationStatus,
  });

  final Job job;
  final bool isFavorite;

  /// null if not applied, else: pending/accepted/rejected...
  final String? applicationStatus;
}

@immutable
class JobsViewModel {
  const JobsViewModel({
    required this.items,
    required this.availableDepartments,
    required this.availableCities,
    required this.availableWorkTypes,
  });

  final List<JobCardVM> items;
  final List<String> availableDepartments;
  final List<String> availableCities;
  final List<String> availableWorkTypes;
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

  JobDetailVm copyWith({JobDetail? job, bool? isFavorited, bool? hasApplied}) {
    return JobDetailVm(
      job: job ?? this.job,
      isFavorited: isFavorited ?? this.isFavorited,
      hasApplied: hasApplied ?? this.hasApplied,
    );
  }
}

@immutable
class JobDetailViewModel {
  const JobDetailViewModel({
    required this.job,
    required this.isFavorite,
    required this.applicationStatus,
  });

  final Job job;
  final bool isFavorite;
  final String? applicationStatus;
}
