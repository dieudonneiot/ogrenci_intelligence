import 'package:flutter/foundation.dart';

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalPoints,
    required this.rank,
    this.department,
  });

  final String userId;
  final String displayName;
  final String? department;
  final int totalPoints;
  final int rank;

  static String displayNameFromProfile(Map<String, dynamic> map) {
    final full = (map['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;

    final email = (map['email'] as String?)?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Anonim';
  }

  factory LeaderboardEntry.fromProfileMap(
    Map<String, dynamic> map, {
    required int rank,
  }) {
    return LeaderboardEntry(
      userId: (map['id'] ?? '').toString(),
      displayName: displayNameFromProfile(map),
      department: (map['department'] as String?)?.trim(),
      totalPoints: (map['total_points'] as int?) ?? 0,
      rank: rank,
    );
  }
}

@immutable
class LeaderboardViewModel {
  const LeaderboardViewModel({
    required this.meId,
    required this.totalPoints,
    required this.overallRank,
    required this.departmentRank,
    required this.department,
    required this.overall,
    required this.departmentList,
  });

  final String meId;

  final int totalPoints;
  final int? overallRank;
  final int? departmentRank;

  final String? department;

  final List<LeaderboardEntry> overall;
  final List<LeaderboardEntry> departmentList;

  static LeaderboardViewModel empty(String meId) {
    return LeaderboardViewModel(
      meId: meId,
      totalPoints: 0,
      overallRank: null,
      departmentRank: null,
      department: null,
      overall: const [],
      departmentList: const [],
    );
  }
}
