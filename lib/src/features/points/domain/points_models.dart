import 'package:flutter/foundation.dart';

int _asInt(dynamic v) => (v is int) ? v : (v as num?)?.toInt() ?? 0;

DateTime _asDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

@immutable
class UserPoint {
  const UserPoint({
    required this.id,
    required this.source,
    required this.description,
    required this.points,
    required this.createdAt,
  });

  final String id;
  final String source;
  final String description;
  final int points;
  final DateTime createdAt;

  factory UserPoint.fromMap(Map<String, dynamic> map) {
    return UserPoint(
      id: map['id'] as String,
      source: (map['source'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      points: _asInt(map['points']),
      createdAt: _asDate(map['created_at']),
    );
  }
}

@immutable
class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredPoints,
    this.department,
    this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int requiredPoints;
  final String? department;
  final String? icon;

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'] as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      requiredPoints: _asInt(map['required_points']),
      department: map['department'] as String?,
      icon: map['icon'] as String?,
    );
  }
}

@immutable
class UserBadge {
  const UserBadge({
    required this.id,
    required this.badgeType,
    required this.badgeTitle,
    this.badgeDescription,
    this.icon,
    required this.earnedAt,
    required this.pointsAwarded,
  });

  final String id;
  final String badgeType;
  final String badgeTitle;
  final String? badgeDescription;
  final String? icon;
  final DateTime earnedAt;
  final int pointsAwarded;

  factory UserBadge.fromMap(Map<String, dynamic> map) {
    return UserBadge(
      id: map['id'] as String,
      badgeType: (map['badge_type'] ?? '') as String,
      badgeTitle: (map['badge_title'] ?? '') as String,
      badgeDescription: map['badge_description'] as String?,
      icon: map['icon'] as String?,
      earnedAt: _asDate(map['earned_at']),
      pointsAwarded: _asInt(map['points_awarded']),
    );
  }
}
