import 'package:flutter/foundation.dart';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse((v ?? '').toString()) ?? 0;
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

@immutable
class TalentCandidate {
  const TalentCandidate({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.department,
    required this.year,
    required this.oiScore,
    required this.metricsAvailable,
    required this.technical,
    required this.social,
    required this.fieldFit,
    required this.consistency,
    required this.totalPoints,
    required this.casesSolved,
    required this.casesLeft,
    required this.casesRight,
    required this.focusSubmitted,
    required this.focusExpired,
    required this.focusAvgSecondsToAnswer,
    required this.nanoCoursesCompleted,
    required this.nanoQuizAttempts,
    required this.nanoQuizCorrect,
    required this.nanoQuizPoints,
    required this.badges,
  });

  final String userId;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? department;
  final int? year;
  final int oiScore;
  final bool metricsAvailable;
  final int technical;
  final int social;
  final int fieldFit;
  final int consistency;
  final int totalPoints;
  final int casesSolved;
  final int casesLeft;
  final int casesRight;
  final int focusSubmitted;
  final int focusExpired;
  final int focusAvgSecondsToAnswer;
  final int nanoCoursesCompleted;
  final int nanoQuizAttempts;
  final int nanoQuizCorrect;
  final int nanoQuizPoints;
  final List<String> badges;

  factory TalentCandidate.fromMap(Map<String, dynamic> map) {
    final metricsAvailable =
        map.containsKey('technical') ||
        map.containsKey('total_points') ||
        map.containsKey('cases_solved') ||
        map.containsKey('focus_avg_seconds_to_answer') ||
        map.containsKey('nano_quiz_attempts');
    return TalentCandidate(
      userId: (map['user_id'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      avatarUrl: (map['avatar_url'] as String?)?.trim(),
      department: (map['department'] as String?)?.trim(),
      year: map['year'] == null ? null : _asInt(map['year']),
      oiScore: _asInt(map['oi_score']).clamp(0, 100),
      metricsAvailable: metricsAvailable,
      technical: _asInt(map['technical']).clamp(0, 100),
      social: _asInt(map['social']).clamp(0, 100),
      fieldFit: _asInt(map['field_fit']).clamp(0, 100),
      consistency: _asInt(map['consistency']).clamp(0, 100),
      totalPoints: _asInt(map['total_points']).clamp(0, 1 << 30),
      casesSolved: _asInt(map['cases_solved']).clamp(0, 1 << 30),
      casesLeft: _asInt(map['cases_left']).clamp(0, 1 << 30),
      casesRight: _asInt(map['cases_right']).clamp(0, 1 << 30),
      focusSubmitted: _asInt(map['focus_submitted']).clamp(0, 1 << 30),
      focusExpired: _asInt(map['focus_expired']).clamp(0, 1 << 30),
      focusAvgSecondsToAnswer: _asInt(
        map['focus_avg_seconds_to_answer'],
      ).clamp(0, 1 << 30),
      nanoCoursesCompleted: _asInt(
        map['nano_courses_completed'],
      ).clamp(0, 1 << 30),
      nanoQuizAttempts: _asInt(map['nano_quiz_attempts']).clamp(0, 1 << 30),
      nanoQuizCorrect: _asInt(map['nano_quiz_correct']).clamp(0, 1 << 30),
      nanoQuizPoints: _asInt(map['nano_quiz_points']).clamp(0, 1 << 30),
      badges: _asStringList(map['badges']),
    );
  }
}
