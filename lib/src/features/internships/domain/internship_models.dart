import 'package:flutter/foundation.dart';

int _asInt(dynamic v) => (v is int) ? v : (v as num?)?.toInt() ?? 0;
bool _asBool(dynamic v) => (v is bool) ? v : (v as bool?) ?? false;

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return DateTime.tryParse(s);
}

List<String> _asStringList(dynamic v) {
  if (v == null) return const <String>[];
  if (v is List) return v.map((e) => e.toString()).toList(growable: false);
  // fallback if PostgREST returns something odd
  return const <String>[];
}

enum InternshipApplicationStatus { pending, accepted, rejected }

InternshipApplicationStatus? _parseStatus(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  switch (s) {
    case 'pending':
      return InternshipApplicationStatus.pending;
    case 'accepted':
      return InternshipApplicationStatus.accepted;
    case 'rejected':
      return InternshipApplicationStatus.rejected;
    default:
      return null;
  }
}

@immutable
class Internship {
  const Internship({
    required this.id,
    required this.title,
    required this.companyName,
    required this.description,
    required this.department,
    required this.location,
    required this.durationMonths,
    required this.isRemote,
    required this.deadline,
    required this.isPaid,
    required this.monthlyStipend,
    required this.providesCertificate,
    required this.possibilityOfEmployment,
    required this.requirements,
    required this.benefits,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String companyName;
  final String description;

  final String? department;
  final String? location;
  final int durationMonths;
  final bool isRemote;

  final DateTime? deadline;

  final bool isPaid;
  final int? monthlyStipend;
  final bool providesCertificate;
  final bool possibilityOfEmployment;

  final List<String> requirements;
  final List<String> benefits;

  final DateTime? createdAt;

  factory Internship.fromMap(Map<String, dynamic> map) {
    return Internship(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      companyName: (map['company_name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      department: (map['department'] as String?)?.trim(),
      location: (map['location'] as String?)?.trim(),
      durationMonths: _asInt(map['duration_months']),
      isRemote: _asBool(map['is_remote']),
      deadline: _asDate(map['deadline']),
      isPaid: _asBool(map['is_paid']),
      monthlyStipend: map['monthly_stipend'] == null ? null : _asInt(map['monthly_stipend']),
      providesCertificate: _asBool(map['provides_certificate']),
      possibilityOfEmployment: _asBool(map['possibility_of_employment']),
      requirements: _asStringList(map['requirements']),
      benefits: _asStringList(map['benefits']),
      createdAt: _asDate(map['created_at']),
    );
  }
}

@immutable
class InternshipApplication {
  const InternshipApplication({
    required this.id,
    required this.internshipId,
    required this.status,
    required this.appliedAt,
  });

  final String id;
  final String internshipId;
  final InternshipApplicationStatus? status;
  final DateTime? appliedAt;

  factory InternshipApplication.fromMap(Map<String, dynamic> map) {
    return InternshipApplication(
      id: (map['id'] ?? '').toString(),
      internshipId: (map['internship_id'] ?? '').toString(),
      status: _parseStatus(map['status']),
      appliedAt: _asDate(map['applied_at']),
    );
  }
}

@immutable
class InternshipCardItem {
  const InternshipCardItem({
    required this.internship,
    required this.isFavorite,
    required this.myApplication,
  });

  final Internship internship;
  final bool isFavorite;
  final InternshipApplication? myApplication;

  InternshipCardItem copyWith({
    Internship? internship,
    bool? isFavorite,
    InternshipApplication? myApplication,
  }) {
    return InternshipCardItem(
      internship: internship ?? this.internship,
      isFavorite: isFavorite ?? this.isFavorite,
      myApplication: myApplication ?? this.myApplication,
    );
  }
}

@immutable
class InternshipsViewModel {
  const InternshipsViewModel({
    required this.department,
    required this.departmentMissing,
    required this.items,
    required this.appliedCount,
  });

  final String? department;
  final bool departmentMissing;

  final List<InternshipCardItem> items;
  final int appliedCount;

  int get activeCount => items.length;

  InternshipsViewModel copyWith({
    String? department,
    bool? departmentMissing,
    List<InternshipCardItem>? items,
    int? appliedCount,
  }) {
    return InternshipsViewModel(
      department: department ?? this.department,
      departmentMissing: departmentMissing ?? this.departmentMissing,
      items: items ?? this.items,
      appliedCount: appliedCount ?? this.appliedCount,
    );
  }

  static InternshipsViewModel empty({String? department, bool departmentMissing = false}) {
    return InternshipsViewModel(
      department: department,
      departmentMissing: departmentMissing,
      items: const <InternshipCardItem>[],
      appliedCount: 0,
    );
  }
}

@immutable
class InternshipDetailViewModel {
  const InternshipDetailViewModel({
    required this.item,
  });

  final InternshipCardItem item;
}
