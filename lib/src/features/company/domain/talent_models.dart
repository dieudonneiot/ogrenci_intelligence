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
    required this.badges,
  });

  final String userId;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? department;
  final int? year;
  final int oiScore;
  final List<String> badges;

  factory TalentCandidate.fromMap(Map<String, dynamic> map) {
    return TalentCandidate(
      userId: (map['user_id'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      avatarUrl: (map['avatar_url'] as String?)?.trim(),
      department: (map['department'] as String?)?.trim(),
      year: map['year'] == null ? null : _asInt(map['year']),
      oiScore: _asInt(map['oi_score']).clamp(0, 100),
      badges: _asStringList(map['badges']),
    );
  }
}
