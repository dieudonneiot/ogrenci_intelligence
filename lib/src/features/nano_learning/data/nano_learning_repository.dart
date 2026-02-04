import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/nano_learning_models.dart';

class NanoLearningRepository {
  NanoLearningRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<NanoVideoCourse>> listFeed({int limit = 20}) async {
    final rows = await _client
        .from('courses')
        .select('id,title,description,department,video_url,created_at')
        .not('video_url', 'is', null)
        .neq('video_url', '')
        .order('created_at', ascending: false)
        .limit(limit) as List<dynamic>;

    return rows
        .map((e) => NanoVideoCourse.fromMap(e as Map<String, dynamic>))
        .where((c) => c.id.isNotEmpty && c.title.trim().isNotEmpty && c.videoUrl.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<NanoQuizQuestion?> getQuizQuestion({required String courseId}) async {
    final raw = await _client.rpc('get_course_quiz_question', params: {'p_course_id': courseId});
    if (raw == null) return null;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final id = (map['question_id'] ?? '').toString();
      if (id.isEmpty) return null;
      return NanoQuizQuestion.fromRpc(map);
    }
    return null;
  }

  Future<NanoQuizSubmitResult> submitQuizAttempt({
    required String courseId,
    required String questionId,
    required int selectedIndex,
    int points = 10,
  }) async {
    final raw = await _client.rpc(
      'submit_course_quiz_attempt',
      params: {
        'p_course_id': courseId,
        'p_question_id': questionId,
        'p_selected_index': selectedIndex,
        'p_points': points,
      },
    );
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return NanoQuizSubmitResult.fromRpc(map);
  }

  Future<void> upsertProgress({
    required String userId,
    required String courseId,
    required int progress,
  }) async {
    final p = progress.clamp(0, 100);
    await _client.from('course_enrollments').upsert(
      {
        'user_id': userId,
        'course_id': courseId,
        'progress': p,
      },
      onConflict: 'user_id,course_id',
    );

    if (p >= 100) {
      await _client.from('completed_courses').upsert(
        {
          'user_id': userId,
          'course_id': courseId,
        },
        onConflict: 'user_id,course_id',
      );
    }
  }
}

