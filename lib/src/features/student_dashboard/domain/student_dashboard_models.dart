import 'package:flutter/foundation.dart';

@immutable
class DashboardStats {
  const DashboardStats({
    required this.totalPoints,
    required this.coursesCompleted,
    required this.activeApplications,
    required this.ongoingCourses,
    this.departmentRank,
  });

  final int totalPoints;
  final int coursesCompleted;
  final int activeApplications;
  final int ongoingCourses;
  final int? departmentRank;
}

@immutable
class EnrolledCourse {
  const EnrolledCourse({
    required this.courseId,
    required this.title,
    required this.description,
    required this.duration,
    required this.level,
    required this.progress,
  });

  final String courseId;
  final String title;
  final String description;
  final String duration;
  final String level;
  final int progress; // 0..100
}

enum ActivityCategory { course, job, internship, achievement, platform }

@immutable
class ActivityItem {
  const ActivityItem({
    required this.category,
    required this.action,
    required this.points,
    required this.createdAt,
  });

  final ActivityCategory category;
  final String action;
  final int points;
  final DateTime createdAt;
}

@immutable
class StudentDashboardVm {
  const StudentDashboardVm({
    required this.displayName,
    required this.stats,
    required this.enrolledCourses,
    required this.activities,
    required this.todayPoints,
    required this.weekPoints,
  });

  final String displayName;
  final DashboardStats stats;
  final List<EnrolledCourse> enrolledCourses;
  final List<ActivityItem> activities;

  final int todayPoints;
  final int weekPoints;
}
