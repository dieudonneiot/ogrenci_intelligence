// lib/src/features/chat/data/chat_repository.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../domain/chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  bool _shouldRefreshSession(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return session.isExpired;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 2)));
  }

  Future<String> _accessToken({
    bool forceRefresh = false,
    Session? sessionOverride,
  }) async {
    var session = sessionOverride ?? _client.auth.currentSession;
    if (session == null) {
      // Attempt recovery (e.g., desktop/web session not yet hydrated).
      try {
        await _client.auth.refreshSession();
      } catch (_) {}
      session = sessionOverride ?? _client.auth.currentSession;
      if (session == null) {
        throw const ChatRepositoryException('Missing auth session');
      }
    }

    if (forceRefresh || _shouldRefreshSession(session)) {
      try {
        // If a caller supplied a session, prefer refreshing via its refresh_token.
        final refreshToken = session.refreshToken;
        if (refreshToken != null && refreshToken.trim().isNotEmpty) {
          await _client.auth.setSession(refreshToken);
        } else {
          await _client.auth.refreshSession();
        }
      } catch (_) {
        // Ignore: if refresh fails we'll surface the real error below.
      }
    }

    final token =
        _client.auth.currentSession?.accessToken ?? session.accessToken;
    if (token.isEmpty) {
      throw const ChatRepositoryException('Missing auth token');
    }

    return token;
  }

  bool _isEdgeFunctionMissing(Object error) {
    final s = error.toString().toLowerCase();
    return s.contains('requested function was not found') ||
        s.contains('not_found') ||
        s.contains('status 404') ||
        s.contains('(404)');
  }

  Future<String> _ensureSessionForFallback(
    String userId, {
    String? sessionId,
  }) async {
    final existing = (sessionId ?? '').trim();
    if (existing.isNotEmpty) return existing;

    final row = await _client
        .from('chat_sessions')
        .insert({
          'user_id': userId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'message_count': 0,
        })
        .select('id')
        .single();

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
    await _insertChatMessage(
      userId: userId,
      sessionId: sid,
      message: message,
      type: 'user',
    );

    String reply;
    try {
      // Prefer full-text search when available (created by docs/sql/15_chatbot_ai.sql)
      final rows = await _client
          .from('chatbot_faqs')
          .select('answer')
          .eq('is_active', true)
          .textSearch(
            'search_vector',
            message,
            type: TextSearchType.plain,
            config: 'simple',
          )
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
    await _insertChatMessage(
      userId: userId,
      sessionId: sid,
      message: reply,
      type: 'bot',
    );

    return ChatAiResponse(
      sessionId: sid,
      reply: reply,
      suggestions: const <String>[],
    );
  }

  Future<List<ChatMessage>> fetchHistory(
    String userId, {
    int limit = 50,
  }) async {
    final res = await _client
        .from('chat_messages')
        .select('id, message, type, created_at, session_id')
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .limit(limit);

    final rows = (res as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<List<ChatSessionSummary>> fetchSessions(
    String userId, {
    int limit = 25,
  }) async {
    final res = await _client
        .from('chat_sessions')
        .select('id, started_at, ended_at, message_count')
        .eq('user_id', userId)
        .order('started_at', ascending: false)
        .limit(limit);

    final rows = (res as List<dynamic>).cast<Map<String, dynamic>>();
    final sessions = rows.map(ChatSessionSummary.fromMap).toList();

    final ids = sessions.map((e) => e.id).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return sessions;

    // Load last message previews in one query and attach on the client.
    // (PostgREST doesn't support "distinct on" easily in a single call.)
    try {
      final msgRes = await _client
          .from('chat_messages')
          .select('session_id, message, created_at')
          .eq('user_id', userId)
          .inFilter('session_id', ids)
          .order('created_at', ascending: false)
          .limit(500);

      final msgRows = (msgRes as List<dynamic>).cast<Map<String, dynamic>>();
      final latestBySession = <String, Map<String, dynamic>>{};
      for (final r in msgRows) {
        final sid = (r['session_id'] ?? '').toString();
        if (sid.isEmpty) continue;
        latestBySession.putIfAbsent(sid, () => r);
      }

      return [
        for (final s in sessions)
          latestBySession.containsKey(s.id)
              ? s.copyWith(
                  lastMessage: (latestBySession[s.id]?['message'] ?? '')
                      .toString()
                      .trim(),
                  lastMessageAt: latestBySession[s.id]?['created_at'] is String
                      ? DateTime.tryParse(
                          latestBySession[s.id]!['created_at'] as String,
                        )
                      : null,
                )
              : s,
      ];
    } catch (_) {
      return sessions;
    }
  }

  Future<List<ChatMessage>> fetchSessionMessages({
    required String userId,
    required String sessionId,
    int limit = 200,
  }) async {
    final res = await _client
        .from('chat_messages')
        .select('id, message, type, created_at, session_id')
        .eq('user_id', userId)
        .eq('session_id', sessionId)
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
    Session? sessionOverride,
  }) async {
    final payload = {
      'message': message,
      'session_id': sessionId,
      'locale': locale,
      'faq_only': faqOnly,
    };

    try {
      final token = await _accessToken(sessionOverride: sessionOverride);
      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'apikey': Env.supabaseAnonKey,
      };

      final response = await _client.functions.invoke(
        'chatbot',
        body: payload,
        headers: headers,
      );
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
          throw const ChatRepositoryException(
            'AI function missing and not authenticated for FAQ fallback',
          );
        }
        return _faqFallback(
          message: message,
          userId: uid,
          sessionId: sessionId,
          locale: locale,
        );
      }
      rethrow;
    }
  }

  Stream<ChatStreamEvent> streamMessage({
    required String message,
    String? sessionId,
    String locale = 'tr',
    bool faqOnly = false,
    Session? sessionOverride,
  }) async* {
    final url = Uri.parse('${Env.supabaseUrl}/functions/v1/chatbot');

    Future<http.StreamedResponse> sendRequest(
      http.Client client, {
      required String token,
    }) {
      final request = http.Request('POST', url);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['apikey'] = Env.supabaseAnonKey;
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';

      request.body = jsonEncode({
        'message': message,
        'session_id': sessionId,
        'locale': locale,
        'faq_only': faqOnly,
        'stream': true,
      });

      return client.send(request);
    }

    final client = http.Client();
    try {
      final uid = _client.auth.currentUser?.id;

      ChatRepositoryException fallbackOrThrow(int status, String body) {
        final lower = body.toLowerCase();

        if (status == 404 && lower.contains('not_found')) {
          return const ChatRepositoryException('__fallback_faq__');
        }

        // If the Edge Function is deployed but not configured (missing AI key, etc),
        // fallback to FAQ so the feature remains usable.
        if (status >= 500 &&
            (lower.contains('missing ai_api_key') ||
                lower.contains('missing openai_api_key') ||
                lower.contains('missing secrets') ||
                lower.contains('missing ai provider'))) {
          return const ChatRepositoryException('__fallback_faq__');
        }

        if (status == 401 && lower.contains('invalid jwt')) {
          return const ChatRepositoryException(
            'Your login session expired. Please log out and log in again.',
          );
        }

        return ChatRepositoryException('Stream error ($status): $body');
      }

      Stream<ChatStreamEvent> faqFallbackStream() async* {
        if (uid == null || uid.isEmpty) {
          throw const ChatRepositoryException(
            'Not authenticated for FAQ fallback',
          );
        }

        final fallback = await _faqFallback(
          message: message,
          userId: uid,
          sessionId: sessionId,
          locale: locale,
        );

        yield ChatStreamEvent(
          type: ChatStreamEventType.meta,
          data: {'session_id': fallback.sessionId},
        );
        final reply = fallback.reply;
        const chunk = 64;
        for (var i = 0; i < reply.length; i += chunk) {
          yield ChatStreamEvent(
            type: ChatStreamEventType.delta,
            data: {
              'text': reply.substring(i, (i + chunk).clamp(0, reply.length)),
            },
          );
        }
        yield ChatStreamEvent(
          type: ChatStreamEventType.done,
          data: {'reply': reply, 'suggestions': fallback.suggestions},
        );
      }

      String token = await _accessToken(sessionOverride: sessionOverride);
      http.StreamedResponse response = await sendRequest(client, token: token);

      // Retry once on Invalid JWT by refreshing the session.
      if (response.statusCode == 401) {
        final body = await response.stream.bytesToString();
        final lower = body.toLowerCase();
        if (lower.contains('invalid jwt')) {
          token = await _accessToken(
            forceRefresh: true,
            sessionOverride: sessionOverride,
          );
          response = await sendRequest(client, token: token);
        } else {
          throw fallbackOrThrow(response.statusCode, body);
        }
      }

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        final ex = fallbackOrThrow(response.statusCode, body);
        if (ex.message == '__fallback_faq__') {
          yield* faqFallbackStream();
          return;
        }
        throw ex;
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
