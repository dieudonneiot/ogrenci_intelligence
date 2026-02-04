import 'package:flutter/foundation.dart';

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

@immutable
class MyExcuseRequest {
  const MyExcuseRequest({
    required this.id,
    required this.reasonType,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewerNote,
  });

  final String id;
  final String reasonType;
  final String? details;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewerNote;

  factory MyExcuseRequest.fromMap(Map<String, dynamic> map) {
    return MyExcuseRequest(
      id: (map['id'] ?? '').toString(),
      reasonType: (map['reason_type'] ?? '').toString(),
      details: (map['details'] as String?)?.trim(),
      status: (map['status'] ?? 'pending').toString(),
      createdAt: _asDate(map['created_at']) ?? DateTime.now().toUtc(),
      reviewedAt: _asDate(map['reviewed_at']),
      reviewerNote: (map['reviewer_note'] as String?)?.trim(),
    );
  }
}

@immutable
class AcceptedInternshipOption {
  const AcceptedInternshipOption({
    required this.applicationId,
    required this.internshipTitle,
    required this.companyName,
  });

  final String applicationId;
  final String internshipTitle;
  final String companyName;
}

@immutable
class CompanyExcuseRequest {
  const CompanyExcuseRequest({
    required this.id,
    required this.userId,
    required this.internshipApplicationId,
    required this.reasonType,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.studentName,
    required this.studentEmail,
    required this.internshipTitle,
    required this.reviewerNote,
    required this.reviewedAt,
  });

  final String id;
  final String userId;
  final String internshipApplicationId;
  final String reasonType;
  final String? details;
  final String status;
  final DateTime createdAt;
  final String studentName;
  final String studentEmail;
  final String internshipTitle;
  final String? reviewerNote;
  final DateTime? reviewedAt;

  factory CompanyExcuseRequest.fromMap(Map<String, dynamic> map) {
    return CompanyExcuseRequest(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      internshipApplicationId: (map['internship_application_id'] ?? '').toString(),
      reasonType: (map['reason_type'] ?? '').toString(),
      details: (map['details'] as String?)?.trim(),
      status: (map['status'] ?? 'pending').toString(),
      createdAt: _asDate(map['created_at']) ?? DateTime.now().toUtc(),
      studentName: (map['student_name'] ?? '').toString(),
      studentEmail: (map['student_email'] ?? '').toString(),
      internshipTitle: (map['internship_title'] ?? '').toString(),
      reviewerNote: (map['reviewer_note'] as String?)?.trim(),
      reviewedAt: _asDate(map['reviewed_at']),
    );
  }
}

