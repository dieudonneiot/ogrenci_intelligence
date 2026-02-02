// lib/src/features/chat/data/chat_repository.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../domain/chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

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

    final response = await _client.functions.invoke('chatbot', body: payload);
    if (response.data == null) {
      throw const ChatRepositoryException('Empty response from AI service');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw ChatRepositoryException(data['error'].toString());
    }
    return ChatAiResponse.fromMap(data);
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
        throw ChatRepositoryException(
          'Stream error (${response.statusCode}): $body',
        );
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
