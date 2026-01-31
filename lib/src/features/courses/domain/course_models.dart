import 'package:flutter/foundation.dart';

@immutable
class Course {
  const Course({
    required this.id,
    required this.title,
    this.description,
    this.department,
    this.duration,
    this.level,
    this.instructor,
    this.category,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.enrolledCount = 0,
    this.videoUrl,
    this.pointsEnrollment = 10,
    this.pointsCompletion = 50,
  });

  final String id;
  final String title;

  final String? description;
  final String? department;
  final String? duration;   // e.g. "4 saat"
  final String? level;      // e.g. "Başlangıç"
  final String? instructor; // e.g. "Dr. X"
  final String? category;   // derived/optional (React concept)

  final double rating;      // derived/optional
  final int totalRatings;   // derived/optional
  final int enrolledCount;  // derived/optional

  final String? videoUrl;

  // UI points (match React concept; later compute from DB/config)
  final int pointsEnrollment;
  final int pointsCompletion;

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      description: map['description'] as String?,
      department: map['department'] as String?,
      videoUrl: map['video_url'] as String?,
      duration: map['duration'] as String?,
      level: map['level'] as String?,
      instructor: map['instructor'] as String?,
      // optional/derived fields (if later you include them in select)
      category: map['category'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (map['total_ratings'] as int?) ?? 0,
      enrolledCount: (map['enrolled_count'] as int?) ?? 0,
    );
  }
}

@immutable
class CourseEnrollment {
  const CourseEnrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.progress,
    this.enrolledAt,
  });

  final String id;
  final String userId;
  final String courseId;
  final int progress; // 0..100
  final DateTime? enrolledAt;

  factory CourseEnrollment.fromMap(Map<String, dynamic> map) {
    return CourseEnrollment(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      courseId: map['course_id'] as String,
      progress: (map['progress'] as int?) ?? 0,
      enrolledAt: map['enrolled_at'] == null
          ? null
          : DateTime.tryParse(map['enrolled_at'].toString()),
    );
  }
}

@immutable
class EnrolledCourse {
  const EnrolledCourse({
    required this.course,
    required this.enrollment,
  });

  final Course course;
  final CourseEnrollment enrollment;
}
