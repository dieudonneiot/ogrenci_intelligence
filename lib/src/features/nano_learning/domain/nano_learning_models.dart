import 'package:flutter/foundation.dart';

@immutable
class NanoVideoCourse {
  const NanoVideoCourse({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.department,
    this.description,
  });

  final String id;
  final String title;
  final String videoUrl;
  final String? department;
  final String? description;

  factory NanoVideoCourse.fromMap(Map<String, dynamic> map) {
    return NanoVideoCourse(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      videoUrl: (map['video_url'] ?? '').toString(),
      department: (map['department'] as String?)?.trim(),
      description: (map['description'] as String?)?.trim(),
    );
  }
}

@immutable
class NanoQuizQuestion {
  const NanoQuizQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<String> options;

  factory NanoQuizQuestion.fromRpc(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = <String>[];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        final s = o?.toString().trim();
        if (s != null && s.isNotEmpty) options.add(s);
      }
    }

    return NanoQuizQuestion(
      id: (map['question_id'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      options: options,
    );
  }
}

@immutable
class NanoQuizSubmitResult {
  const NanoQuizSubmitResult({
    required this.isCorrect,
    required this.pointsAwarded,
  });

  final bool isCorrect;
  final int pointsAwarded;

  factory NanoQuizSubmitResult.fromRpc(Map<String, dynamic> map) {
    final isCorrect = map['is_correct'] == true;
    final points = (map['points_awarded'] is num)
        ? (map['points_awarded'] as num).toInt()
        : 0;
    return NanoQuizSubmitResult(isCorrect: isCorrect, pointsAwarded: points);
  }
}
