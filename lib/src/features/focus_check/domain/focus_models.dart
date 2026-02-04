import 'package:flutter/foundation.dart';

@immutable
class AcceptedInternshipApplication {
  const AcceptedInternshipApplication({
    required this.applicationId,
    required this.internshipId,
    required this.companyId,
    required this.internshipTitle,
    required this.companyName,
  });

  final String applicationId;
  final String internshipId;
  final String companyId;
  final String internshipTitle;
  final String companyName;

  factory AcceptedInternshipApplication.fromMap(Map<String, dynamic> map) {
    final internship = (map['internship'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return AcceptedInternshipApplication(
      applicationId: (map['id'] ?? '').toString(),
      internshipId: (map['internship_id'] ?? '').toString(),
      companyId: (internship['company_id'] ?? '').toString(),
      internshipTitle: (internship['title'] ?? '').toString(),
      companyName: (internship['company_name'] ?? '').toString(),
    );
  }
}

@immutable
class FocusCheckSession {
  const FocusCheckSession({
    required this.id,
    required this.question,
    required this.expiresAt,
  });

  final String id;
  final String question;
  final DateTime expiresAt;

  factory FocusCheckSession.fromMap(Map<String, dynamic> map) {
    final expires = DateTime.tryParse((map['expires_at'] ?? '').toString())?.toUtc() ?? DateTime.now().toUtc();
    return FocusCheckSession(
      id: (map['focus_check_id'] ?? map['id'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      expiresAt: expires,
    );
  }
}

