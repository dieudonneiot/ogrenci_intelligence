import 'package:flutter/foundation.dart';

int _asInt(dynamic v) => (v is int) ? v : (v as num?)?.toInt() ?? 0;

DateTime _asDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

enum ApplicationKind { job, internship, course }

enum ApplicationStatus { pending, accepted, rejected, active, completed }

@immutable
class ApplicationListItem {
  const ApplicationListItem({
    required this.kind,
    required this.id,
    required this.refId,
    required this.title,
    required this.status,
    required this.date,
    this.subtitle,
    this.department,
    this.meta,
    this.progress,
  });

  final ApplicationKind kind;

  /// Primary row id (e.g. internship_applications.id or course_enrollments.id)
  final String id;

  /// The referenced entity id (internship_id / course_id / job_id)
  final String refId;

  final String title;
  final String? subtitle; // e.g. company name (internship)
  final String? department; // e.g. department
  final String? meta; // e.g. location/level/duration label

  final ApplicationStatus status;
  final DateTime date;

  /// For courses only (0..100)
  final int? progress;

  String get searchBlob {
    final parts = <String>[
      title,
      subtitle ?? '',
      department ?? '',
      meta ?? '',
      status.name,
      kind.name,
    ];
    return parts.join(' ').toLowerCase();
  }

  static ApplicationStatus _statusFromInternship(String? s) {
    switch ((s ?? '').trim().toLowerCase()) {
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'pending':
      default:
        return ApplicationStatus.pending;
    }
  }

  static ApplicationStatus _statusFromCourse({
    required int progress,
    required bool completed,
  }) {
    if (completed || progress >= 100) return ApplicationStatus.completed;
    return ApplicationStatus.active;
  }

  factory ApplicationListItem.fromInternshipApplicationMap(Map<String, dynamic> map) {
    final internship = (map['internship'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final title = (internship['title'] ?? '') as String;
    final company = (internship['company_name'] ?? '') as String;
    final dept = (internship['department'] as String?)?.trim();

    final location = (internship['location'] as String?)?.trim();
    final isRemote = (internship['is_remote'] == true);
    final workType = (internship['work_type'] as String?)?.trim();
    final durationMonths = internship['duration_months'];

    final meta = <String>[
      if (location != null && location.isNotEmpty) location,
      if (isRemote) 'Remote',
      if (workType != null && workType.isNotEmpty) workType,
      if (durationMonths != null) '${_asInt(durationMonths)} ay',
    ].where((e) => e.isNotEmpty).join(' • ');

    return ApplicationListItem(
      kind: ApplicationKind.internship,
      id: (map['id'] ?? '').toString(),
      refId: (map['internship_id'] ?? '').toString(),
      title: title.isNotEmpty ? title : 'Staj',
      subtitle: company.isNotEmpty ? company : null,
      department: dept,
      meta: meta.isNotEmpty ? meta : null,
      status: _statusFromInternship(map['status'] as String?),
      date: _asDate(map['applied_at']),
    );
  }

  factory ApplicationListItem.fromCourseEnrollmentMap(
    Map<String, dynamic> map, {
    required DateTime? completedAt,
  }) {
    final course = (map['course'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final title = (course['title'] ?? '') as String;
    final dept = (course['department'] as String?)?.trim();
    final level = (course['level'] as String?)?.trim();
    final duration = (course['duration'] as String?)?.trim();

    final progress = _asInt(map['progress']);
    final status = _statusFromCourse(progress: progress, completed: completedAt != null);

    final meta = <String>[
      if (level != null && level.isNotEmpty) level,
      if (duration != null && duration.isNotEmpty) duration,
      'İlerleme: %$progress',
    ].join(' • ');

    return ApplicationListItem(
      kind: ApplicationKind.course,
      id: (map['id'] ?? '').toString(),
      refId: (map['course_id'] ?? '').toString(),
      title: title.isNotEmpty ? title : 'Kurs',
      department: dept,
      meta: meta,
      progress: progress,
      status: status,
      date: completedAt ?? _asDate(map['enrolled_at']),
    );
  }
}

@immutable
class ApplicationsBundle {
  const ApplicationsBundle({
    required this.internships,
    required this.courses,
  });

  final List<ApplicationListItem> internships;
  final List<ApplicationListItem> courses;

  factory ApplicationsBundle.empty() => const ApplicationsBundle(internships: [], courses: []);

  List<ApplicationListItem> get all {
    final list = <ApplicationListItem>[...internships, ...courses];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  int get total => internships.length + courses.length;

  int countStatus(ApplicationStatus s) => all.where((e) => e.status == s).length;
}
