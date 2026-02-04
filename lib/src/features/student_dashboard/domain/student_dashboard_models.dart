import 'package:flutter/foundation.dart';

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
class DashboardEnrolledCourse {
  const DashboardEnrolledCourse({
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

@immutable
class StudentDashboardStats {
  const StudentDashboardStats({
    required this.totalPoints,
    required this.coursesCompleted,
    required this.activeApplications,
    required this.ongoingCourses,
    required this.daysAttendedThisMonth,
    required this.casesSolved,
    this.departmentRank,
  });

  final int totalPoints;
  final int coursesCompleted;
  final int activeApplications;
  final int ongoingCourses;
  final int daysAttendedThisMonth;
  final int casesSolved;
  final int? departmentRank;
}

@immutable
class DashboardRecommendedCourse {
  const DashboardRecommendedCourse({
    required this.id,
    required this.title,
    required this.department,
    required this.videoUrl,
  });

  final String id;
  final String title;
  final String? department;
  final String? videoUrl;
}

@immutable
class DashboardTaskSummary {
  const DashboardTaskSummary({
    required this.hasAcceptedInternship,
    required this.pendingEvidenceCount,
    required this.unansweredCaseCount,
  });

  final bool hasAcceptedInternship;
  final int pendingEvidenceCount;
  final int unansweredCaseCount;
}

@immutable
class StudentDashboardViewModel {
  const StudentDashboardViewModel({
    required this.displayName,
    required this.stats,
    required this.todayPoints,
    required this.weekPoints,
    required this.enrolledCourses,
    required this.activities,
    required this.recommendedCourses,
    required this.tasks,
  });

  final String displayName;
  final StudentDashboardStats stats;

  final int todayPoints;
  final int weekPoints;

  final List<DashboardEnrolledCourse> enrolledCourses;
  final List<ActivityItem> activities;
  final List<DashboardRecommendedCourse> recommendedCourses;
  final DashboardTaskSummary tasks;

  static StudentDashboardViewModel empty({String displayName = 'Öğrenci'}) {
    return StudentDashboardViewModel(
      displayName: displayName,
      stats: const StudentDashboardStats(
        totalPoints: 0,
        coursesCompleted: 0,
        activeApplications: 0,
        ongoingCourses: 0,
        daysAttendedThisMonth: 0,
        casesSolved: 0,
        departmentRank: null,
      ),
      todayPoints: 0,
      weekPoints: 0,
      enrolledCourses: const <DashboardEnrolledCourse>[],
      activities: const <ActivityItem>[],
      recommendedCourses: const <DashboardRecommendedCourse>[],
      tasks: const DashboardTaskSummary(
        hasAcceptedInternship: false,
        pendingEvidenceCount: 0,
        unansweredCaseCount: 0,
      ),
    );
  }
}
