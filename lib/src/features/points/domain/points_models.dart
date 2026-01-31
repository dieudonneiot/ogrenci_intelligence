import 'package:flutter/foundation.dart';

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
      points: (map['points'] ?? 0) as int,
      createdAt: DateTime.tryParse((map['created_at'] ?? '') as String) ?? DateTime.now(),
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
      requiredPoints: (map['required_points'] ?? 0) as int,
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
      earnedAt: DateTime.tryParse((map['earned_at'] ?? '') as String) ?? DateTime.now(),
      pointsAwarded: (map['points_awarded'] ?? 0) as int,
    );
  }
}
