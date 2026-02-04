import 'package:flutter/foundation.dart';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
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
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.tryParse(v.toString());
}

String? _asTrimmedString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<String> _splitList(String? text) {
  final raw = (text ?? '').trim();
  if (raw.isEmpty) return const <String>[];
  final normalized = raw.replaceAll('\n', ',');
  return normalized
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

List<String> _asStringList(dynamic v) {
  if (v == null) return const <String>[];
  if (v is List) {
    return v
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return _splitList(v.toString());
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
    case '':
      return InternshipApplicationStatus.pending;
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
    this.isActive = true,
    this.compatibility = 0,
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
  final double? monthlyStipend;
  final bool providesCertificate;
  final bool possibilityOfEmployment;

  final List<String> requirements;
  final List<String> benefits;

  final DateTime? createdAt;
  final bool isActive;
  final int compatibility; // 0..100

  Internship copyWith({int? compatibility}) {
    return Internship(
      id: id,
      title: title,
      companyName: companyName,
      description: description,
      department: department,
      location: location,
      durationMonths: durationMonths,
      isRemote: isRemote,
      deadline: deadline,
      isPaid: isPaid,
      monthlyStipend: monthlyStipend,
      providesCertificate: providesCertificate,
      possibilityOfEmployment: possibilityOfEmployment,
      requirements: requirements,
      benefits: benefits,
      createdAt: createdAt,
      isActive: isActive,
      compatibility: (compatibility ?? this.compatibility).clamp(0, 100),
    );
  }

  factory Internship.fromMap(Map<String, dynamic> map) {
    return Internship(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      companyName: (map['company_name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      department: _asTrimmedString(map['department']),
      location: _asTrimmedString(map['location']),
      durationMonths: _asInt(map['duration_months']),
      isRemote: _asBool(map['is_remote']),
      deadline: _asDate(map['deadline']),
      isPaid: _asBool(map['is_paid']),
      monthlyStipend: _asDouble(map['monthly_stipend']),
      providesCertificate: _asBool(map['provides_certificate']),
      possibilityOfEmployment: _asBool(map['possibility_of_employment']),
      requirements: _asStringList(map['requirements']),
      benefits: _asStringList(map['benefits']),
      createdAt: _asDate(map['created_at']),
      isActive: map.containsKey('is_active') ? _asBool(map['is_active']) : true,
      compatibility: 0,
    );
  }

  static List<String> splitList(String? text) => _splitList(text);
}

@immutable
class InternshipApplication {
  const InternshipApplication({
    required this.id,
    required this.internshipId,
    required this.status,
    required this.appliedAt,
    this.userId,
    this.motivationLetter,
  });

  final String id;
  final String internshipId;
  final InternshipApplicationStatus? status;
  final DateTime? appliedAt;
  final String? userId;
  final String? motivationLetter;

  factory InternshipApplication.fromMap(Map<String, dynamic> map) {
    return InternshipApplication(
      id: (map['id'] ?? '').toString(),
      internshipId: (map['internship_id'] ?? '').toString(),
      status: _parseStatus(map['status']),
      appliedAt: _asDate(map['applied_at']),
      userId: _asTrimmedString(map['user_id']),
      motivationLetter: _asTrimmedString(map['motivation_letter']),
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
