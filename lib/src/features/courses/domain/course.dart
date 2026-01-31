import 'package:flutter/foundation.dart';

@immutable
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.duration,
    required this.level,
    required this.instructor,
    required this.category,
    required this.rating,
    required this.totalRatings,
    required this.enrolledCount,
    this.videoUrl,
    this.pointsEnrollment = 10,
    this.pointsCompletion = 50,
  });

  final String id;
  final String title;
  final String description;
  final String department;
  final String duration;   // e.g. "4 saat"
  final String level;      // e.g. "Başlangıç"
  final String instructor; // e.g. "Dr. X"
  final String category;   // e.g. "Temel Dersler"
  final double rating;     // 0..5
  final int totalRatings;
  final int enrolledCount;

  final String? videoUrl;

  // UI points (match React concept; later compute from DB or config)
  final int pointsEnrollment;
  final int pointsCompletion;
}
