import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nano_learning_repository.dart';
import '../domain/nano_learning_models.dart';

final nanoLearningRepositoryProvider = Provider<NanoLearningRepository>((ref) {
  return NanoLearningRepository();
});

final nanoLearningFeedProvider =
    FutureProvider.autoDispose<List<NanoVideoCourse>>((ref) async {
      return ref.watch(nanoLearningRepositoryProvider).listFeed(limit: 25);
    });

final nanoQuizQuestionProvider = FutureProvider.autoDispose
    .family<NanoQuizQuestion?, String>((ref, courseId) async {
      if (courseId.trim().isEmpty) return null;
      return ref
          .watch(nanoLearningRepositoryProvider)
          .getQuizQuestion(courseId: courseId);
    });
