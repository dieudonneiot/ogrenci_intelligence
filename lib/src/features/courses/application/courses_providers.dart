import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/courses_repository.dart';
import '../domain/course_models.dart';

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepository();
});

// Filters
final coursesSearchProvider = StateProvider<String>((ref) => '');
final coursesDepartmentProvider = StateProvider<String?>((ref) => null);
final coursesLevelProvider = StateProvider<String?>((ref) => null);

// All courses (filtered)
final coursesListProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  final search = ref.watch(coursesSearchProvider);
  final dept = ref.watch(coursesDepartmentProvider);
  final level = ref.watch(coursesLevelProvider);

  return repo.listCourses(
    search: search,
    department: dept,
    level: level,
  );
});

// My enrolled courses (includes real progress)
final myEnrolledCoursesProvider =
    FutureProvider.autoDispose<List<EnrolledCourse>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  final auth = ref.watch(authViewStateProvider).value;
  final uid = auth?.user?.id;

  if (uid == null || uid.isEmpty) return <EnrolledCourse>[];
  return repo.listMyEnrolledCourses(uid);
});

// Course detail
final courseDetailProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, courseId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourseById(courseId);
});

// Enrollment for a specific course (detail screen progress)
final myCourseEnrollmentProvider =
    FutureProvider.autoDispose.family<CourseEnrollment?, String>((ref, courseId) async {
  final repo = ref.watch(coursesRepositoryProvider);
  final auth = ref.watch(authViewStateProvider).value;
  final uid = auth?.user?.id;

  if (uid == null || uid.isEmpty) return null;
  return repo.getMyEnrollment(userId: uid, courseId: courseId);
});
