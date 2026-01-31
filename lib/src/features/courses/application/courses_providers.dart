import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/courses_repository.dart';
import '../data/fake_courses_repository.dart';
import '../presentation/state/courses_controller.dart';

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return FakeCoursesRepository();
});

final coursesControllerProvider =
    StateNotifierProvider<CoursesController, CoursesState>((ref) {
  final repo = ref.watch(coursesRepositoryProvider);
  return CoursesController(repo)..load();
});
