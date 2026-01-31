import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/courses_repository.dart';
import '../../domain/course_models.dart';

@immutable
class CoursesState {
  const CoursesState({
    this.isLoading = false,
    this.error,
    this.query = '',
    this.category = 'Tümü',
    this.courses = const <Course>[],
    this.favorites = const <String>{},
    this.enrolled = const <String>{},
    this.completed = const <String>{},
    this.progressByCourse = const <String, int>{}, // 0..100
    this.earnedPoints = 0,
    this.enrollmentPointsGiven = const <String>{},
    this.completionPointsGiven = const <String>{},
  });

  final bool isLoading;
  final String? error;

  final String query;
  final String category;

  final List<Course> courses;

  final Set<String> favorites;
  final Set<String> enrolled;
  final Set<String> completed;

  final Map<String, int> progressByCourse;

  final int earnedPoints;

  // prevent double-award in UI-first mode
  final Set<String> enrollmentPointsGiven;
  final Set<String> completionPointsGiven;

  CoursesState copyWith({
    bool? isLoading,
    String? error,
    String? query,
    String? category,
    List<Course>? courses,
    Set<String>? favorites,
    Set<String>? enrolled,
    Set<String>? completed,
    Map<String, int>? progressByCourse,
    int? earnedPoints,
    Set<String>? enrollmentPointsGiven,
    Set<String>? completionPointsGiven,
  }) {
    return CoursesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
      category: category ?? this.category,
      courses: courses ?? this.courses,
      favorites: favorites ?? this.favorites,
      enrolled: enrolled ?? this.enrolled,
      completed: completed ?? this.completed,
      progressByCourse: progressByCourse ?? this.progressByCourse,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      enrollmentPointsGiven: enrollmentPointsGiven ?? this.enrollmentPointsGiven,
      completionPointsGiven: completionPointsGiven ?? this.completionPointsGiven,
    );
  }
}

class CoursesController extends StateNotifier<CoursesState> {
  CoursesController(this._repo) : super(const CoursesState());

  final CoursesRepository _repo;

  static const categories = <String>[
    'Tümü',
    'Temel Dersler',
    'Alan Dersleri',
    'Seçmeli Dersler',
    'Yazılım',
    'Veri Bilimi',
    'Kariyer',
    'Kişisel Gelişim',
  ];

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // DB fetch (title search supported). Category is UI-only for now.
      final list = await _repo.listCourses(
        search: state.query,
        department: null,
        level: null,
      );

      // If category filter is used, filter locally (since DB has no "category" yet)
      final filtered = (state.category == 'Tümü')
          ? list
          : list.where((c) => (c.category ?? '') == state.category).toList();

      state = state.copyWith(isLoading: false, courses: filtered);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setQuery(String v) {
    state = state.copyWith(query: v);
    // optional: auto reload on query change
    // unawaited(load());
  }

  void setCategory(String v) {
    state = state.copyWith(category: v);
    // optional: auto reload (since we filter locally, no need)
    // state = state.copyWith(courses: ...)
  }

  void toggleFavorite(String courseId) {
    final next = {...state.favorites};
    if (next.contains(courseId)) {
      next.remove(courseId);
    } else {
      next.add(courseId);
    }
    state = state.copyWith(favorites: next);
  }

  void enroll(String courseId) {
    if (state.enrolled.contains(courseId)) return;

    final nextEnrolled = {...state.enrolled, courseId};
    final nextProgress = {...state.progressByCourse, courseId: 0};

    // award enrollment points once
    var earned = state.earnedPoints;
    final given = {...state.enrollmentPointsGiven};

    final course = state.courses.firstWhereOrNull((c) => c.id == courseId);
    if (!given.contains(courseId) && course != null) {
      earned += course.pointsEnrollment;
      given.add(courseId);
    }

    state = state.copyWith(
      enrolled: nextEnrolled,
      progressByCourse: nextProgress,
      earnedPoints: earned,
      enrollmentPointsGiven: given,
    );
  }

  void markModuleComplete(String courseId, int moduleIndex, {int totalModules = 5}) {
    if (!state.enrolled.contains(courseId)) return;

    final target = (((moduleIndex + 1) / totalModules) * 100).round().clamp(0, 100);
    final current = state.progressByCourse[courseId] ?? 0;
    if (target <= current) return;

    final next = {...state.progressByCourse, courseId: target};
    state = state.copyWith(progressByCourse: next);
  }

  void completeCourse(String courseId) {
    if (!state.enrolled.contains(courseId)) return;

    final nextCompleted = {...state.completed, courseId};
    final nextProgress = {...state.progressByCourse, courseId: 100};

    // award completion points once
    var earned = state.earnedPoints;
    final given = {...state.completionPointsGiven};

    final course = state.courses.firstWhereOrNull((c) => c.id == courseId);
    if (!given.contains(courseId) && course != null) {
      earned += course.pointsCompletion;
      given.add(courseId);
    }

    state = state.copyWith(
      completed: nextCompleted,
      progressByCourse: nextProgress,
      earnedPoints: earned,
      completionPointsGiven: given,
    );
  }
}

extension _IterableX<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E e) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
