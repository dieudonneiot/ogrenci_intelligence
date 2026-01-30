// lib/src/features/student/domain/student_dashboard_models.dart

class StudentProfile {
  const StudentProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.department,
    required this.year,
    required this.totalPoints,
  });

  final String userId;
  final String email;
  final String fullName;
  final String department;
  final int year;
  final int totalPoints;

  StudentProfile copyWith({
    String? fullName,
    String? department,
    int? year,
    int? totalPoints,
  }) {
    return StudentProfile(
      userId: userId,
      email: email,
      fullName: fullName ?? this.fullName,
      department: department ?? this.department,
      year: year ?? this.year,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }
}

class EnrolledCourse {
  const EnrolledCourse({
    required this.enrollmentId,
    required this.courseId,
    required this.title,
    required this.description,
    required this.duration,
    required this.level,
    required this.progress, // 0..100
    required this.enrolledAt,
  });

  final String enrollmentId;
  final String courseId;
  final String title;
  final String description;
  final String duration;
  final String level;
  final int progress;
  final DateTime? enrolledAt;
}

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.description,
    required this.points,
    required this.createdAt,
  });

  final String type;
  final String description;
  final int points;
  final DateTime? createdAt;
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.profile,
    required this.completedCourses,
    required this.activeApplications,
    required this.enrolledCourses,
    required this.recentActivities,
  });

  final StudentProfile profile;
  final int completedCourses;
  final int activeApplications;
  final List<EnrolledCourse> enrolledCourses;
  final List<ActivityItem> recentActivities;
}
