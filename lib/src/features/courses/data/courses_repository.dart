import '../domain/course.dart';

abstract class CoursesRepository {
  Future<List<Course>> fetchCourses({String? department});
  Future<Course?> fetchCourseById(String id);
}
