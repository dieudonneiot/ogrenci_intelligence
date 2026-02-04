import 'package:flutter/foundation.dart';

enum EvidenceStatus { pending, approved, rejected }

@immutable
class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.internshipApplicationId,
    required this.filePath,
    required this.status,
    required this.createdAt,
    this.title,
    this.description,
    this.mimeType,
    this.sizeBytes,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String companyId;
  final String internshipApplicationId;
  final String filePath;
  final EvidenceStatus status;
  final DateTime createdAt;

  final String? title;
  final String? description;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? updatedAt;

  static EvidenceStatus _status(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
        return EvidenceStatus.approved;
      case 'rejected':
        return EvidenceStatus.rejected;
      case 'pending':
      default:
        return EvidenceStatus.pending;
    }
  }

  static DateTime _dt(dynamic v) {
    final s = v?.toString();
    final dt = s == null ? null : DateTime.tryParse(s);
    return dt?.toUtc() ?? DateTime.now().toUtc();
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  factory EvidenceItem.fromMap(Map<String, dynamic> map) {
    return EvidenceItem(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      companyId: (map['company_id'] ?? '').toString(),
      internshipApplicationId: (map['internship_application_id'] ?? '').toString(),
      filePath: (map['file_path'] ?? '').toString(),
      title: (map['title'] as String?)?.trim(),
      description: (map['description'] as String?)?.trim(),
      mimeType: (map['mime_type'] as String?)?.trim(),
      sizeBytes: _asInt(map['size_bytes']),
      status: _status(map['status']?.toString()),
      createdAt: _dt(map['created_at']),
      updatedAt: map['updated_at'] == null ? null : _dt(map['updated_at']),
    );
  }
}

@immutable
class EvidenceUploadDraft {
  const EvidenceUploadDraft({
    required this.internshipApplicationId,
    required this.title,
    required this.description,
  });

  final String internshipApplicationId;
  final String title;
  final String description;
}

