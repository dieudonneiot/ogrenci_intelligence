// lib/src/features/chat/data/chat_repository.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../domain/chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  bool _isEdgeFunctionMissing(Object error) {
    final s = error.toString().toLowerCase();
    return s.contains('requested function was not found') || s.contains('not_found') || s.contains('status 404') || s.contains('(404)');
  }

  Future<String> _ensureSessionForFallback(String userId, {String? sessionId}) async {
    final existing = (sessionId ?? '').trim();
    if (existing.isNotEmpty) return existing;

    final row = await _client.from('chat_sessions').insert({
      'user_id': userId,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'message_count': 0,
    }).select('id').single();

    return (row['id'] ?? '').toString();
  }

  Future<void> _insertChatMessage({
    required String userId,
    required String sessionId,
    required String message,
    required String type, // user|bot
  }) async {
    await _client.from('chat_messages').insert({
      'user_id': userId,
      'session_id': sessionId,
      'message': message,
      'type': type,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<ChatAiResponse> _faqFallback({
    required String message,
    required String userId,
    String? sessionId,
    required String locale,
  }) async {
    final sid = await _ensureSessionForFallback(userId, sessionId: sessionId);

    // Persist the user message.
    await _insertChatMessage(userId: userId, sessionId: sid, message: message, type: 'user');

    String reply;
    try {
      // Prefer full-text search when available (created by docs/sql/15_chatbot_ai.sql)
      final rows = await _client
          .from('chatbot_faqs')
          .select('answer')
          .eq('is_active', true)
          .textSearch('search_vector', message, type: TextSearchType.plain, config: 'simple')
          .limit(1);

      final list = (rows as List).cast<Map<String, dynamic>>();
      reply = list.isEmpty ? '' : (list.first['answer'] ?? '').toString();
    } catch (_) {
      reply = '';
    }

    if (reply.trim().isEmpty) {
      // Soft fallback: try ILIKE over question/answer/keywords.
      try {
        final q = message.replaceAll('%', '').replaceAll('_', '').trim();
        final pat = '%$q%';
        final rows = await _client
            .from('chatbot_faqs')
            .select('answer')
            .eq('is_active', true)
            .or('question.ilike.$pat,answer.ilike.$pat')
            .limit(1);
        final list = (rows as List).cast<Map<String, dynamic>>();
        reply = list.isEmpty ? '' : (list.first['answer'] ?? '').toString();
      } catch (_) {
        // ignore
      }
    }

    if (reply.trim().isEmpty) {
      reply = locale.toLowerCase().startsWith('en')
          ? 'The AI service is not deployed for this project yet, and I could not find a matching FAQ.'
          : 'AI servisi bu projede henuz yayinda degil ve uygun bir SSS cevabi bulunamadi.';
    }

    // Persist bot reply.
    await _insertChatMessage(userId: userId, sessionId: sid, message: reply, type: 'bot');

    return ChatAiResponse(
      sessionId: sid,
      reply: reply,
      suggestions: const <String>[],
    );
  }

  Future<List<ChatMessage>> fetchHistory(String userId, {int limit = 50}) async {
    final res = await _client
        .from('chat_messages')
        .select('id, message, type, created_at, session_id')
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .limit(limit);

    final rows = (res as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<ChatAiResponse> sendMessage({
    required String message,
    String? sessionId,
    String locale = 'tr',
    bool faqOnly = false,
  }) async {
    final payload = {
      'message': message,
      'session_id': sessionId,
      'locale': locale,
      'faq_only': faqOnly,
    };

    try {
      final response = await _client.functions.invoke('chatbot', body: payload);
      if (response.data == null) {
        throw const ChatRepositoryException('Empty response from AI service');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw ChatRepositoryException(data['error'].toString());
      }
      return ChatAiResponse.fromMap(data);
    } catch (e) {
      if (_isEdgeFunctionMissing(e)) {
        final uid = _client.auth.currentUser?.id;
        if (uid == null || uid.isEmpty) {
          throw const ChatRepositoryException('AI function missing and not authenticated for FAQ fallback');
        }
        return _faqFallback(message: message, userId: uid, sessionId: sessionId, locale: locale);
      }
      rethrow;
    }
  }

  Stream<ChatStreamEvent> streamMessage({
    required String message,
    String? sessionId,
    String locale = 'tr',
    bool faqOnly = false,
  }) async* {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ChatRepositoryException('Missing auth token');
    }

    final url = Uri.parse('${Env.supabaseUrl}/functions/v1/chatbot');
    final request = http.Request('POST', url);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['apikey'] = Env.supabaseAnonKey;
    request.headers['Content-Type'] = 'application/json';

    request.body = jsonEncode({
      'message': message,
      'session_id': sessionId,
      'locale': locale,
      'faq_only': faqOnly,
      'stream': true,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();

        // If the Edge Function is not deployed yet, fallback to FAQ using DB.
        if (response.statusCode == 404 && body.toLowerCase().contains('not_found')) {
          final uid = _client.auth.currentUser?.id;
          if (uid == null || uid.isEmpty) {
            throw const ChatRepositoryException('AI function missing and not authenticated for FAQ fallback');
          }

          final fallback = await _faqFallback(message: message, userId: uid, sessionId: sessionId, locale: locale);

          // Emit a minimal stream-like response.
          yield ChatStreamEvent(type: ChatStreamEventType.meta, data: {'session_id': fallback.sessionId});
          final reply = fallback.reply;
          const chunk = 64;
          for (var i = 0; i < reply.length; i += chunk) {
            yield ChatStreamEvent(
              type: ChatStreamEventType.delta,
              data: {'text': reply.substring(i, (i + chunk).clamp(0, reply.length))},
            );
          }
          yield ChatStreamEvent(type: ChatStreamEventType.done, data: {'reply': reply, 'suggestions': fallback.suggestions});
          return;
        }

        throw ChatRepositoryException('Stream error (${response.statusCode}): $body');
      }

      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        buffer = buffer.replaceAll('\r\n', '\n');

        while (true) {
          final idx = buffer.indexOf('\n\n');
          if (idx == -1) break;

          final rawEvent = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          final event = _parseSseEvent(rawEvent);
          if (event != null) {
            yield event;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<void> endSession(String sessionId, {int? messageCount}) async {
    final updates = <String, dynamic>{
      'ended_at': DateTime.now().toIso8601String(),
    };

    if (messageCount != null) {
      updates['message_count'] = messageCount;
    }

    await _client.from('chat_sessions').update(updates).eq('id', sessionId);
  }
}

ChatStreamEvent? _parseSseEvent(String rawEvent) {
  final lines = rawEvent.split('\n');
  String? eventType;
  final dataLines = <String>[];

  for (final line in lines) {
    if (line.startsWith('event:')) {
      eventType = line.substring(6).trim();
      continue;
    }
    if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).trimLeft());
    }
  }

  if (dataLines.isEmpty) return null;
  final dataStr = dataLines.join('\n');

  Map<String, dynamic> data;
  try {
    final decoded = jsonDecode(dataStr);
    if (decoded is Map<String, dynamic>) {
      data = decoded;
    } else {
      data = {'text': decoded.toString()};
    }
  } catch (_) {
    data = {'text': dataStr};
  }

  final type = switch (eventType) {
    'meta' => ChatStreamEventType.meta,
    'done' => ChatStreamEventType.done,
    'error' => ChatStreamEventType.error,
    _ => ChatStreamEventType.delta,
  };

  return ChatStreamEvent(type: type, data: data);
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
