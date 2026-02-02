// lib/src/features/chat/presentation/controllers/chat_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_models.dart';

class ChatState {
  const ChatState({
    required this.messages,
    required this.isLoading,
    required this.isTyping,
    required this.suggestions,
    required this.sessionId,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isTyping;
  final List<String> suggestions;
  final String? sessionId;
  final String? error;

  factory ChatState.initial() {
    return const ChatState(
      messages: [],
      isLoading: false,
      isTyping: false,
      suggestions: [],
      sessionId: null,
    );
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isTyping,
    List<String>? suggestions,
    String? sessionId,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
      suggestions: suggestions ?? this.suggestions,
      sessionId: sessionId ?? this.sessionId,
      error: error,
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(SupabaseService.client);
});

final chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  (ref, userId) {
    final controller = ChatController(ref, userId);
    ref.onDispose(controller.close);
    return controller;
  },
);

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref, this._userId) : super(ChatState.initial());

  final Ref _ref;
  final String _userId;
  bool _loaded = false;
  String? _activeSessionId;

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);

  Future<void> loadHistory({String? userName}) async {
    if (_loaded || state.isLoading) return;
    _loaded = true;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final history = await _repo.fetchHistory(_userId);
      if (history.isEmpty) {
        state = state.copyWith(
          messages: [_greetingMessage(userName)],
          suggestions: _defaultSuggestions(),
        );
      } else {
        _activeSessionId = history.last.sessionId;
        state = state.copyWith(messages: history);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Gecmis yuklenemedi: $e',
        messages: [_greetingMessage(userName)],
        suggestions: _defaultSuggestions(),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> sendMessage(String text, {String locale = 'tr'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isTyping) return;

    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: 'local-${now.microsecondsSinceEpoch}',
      message: trimmed,
      type: ChatMessageType.user,
      createdAt: now,
      sessionId: _activeSessionId,
      isLocal: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      suggestions: const [],
      error: null,
    );

    try {
      await _streamResponse(trimmed, locale: locale);
    } catch (e) {
      final botMessage = ChatMessage(
        id: 'bot-${DateTime.now().microsecondsSinceEpoch}',
        message: 'Uzgunum, su an yanit veremiyorum. Lutfen tekrar deneyin.',
        type: ChatMessageType.bot,
        createdAt: DateTime.now(),
        sessionId: _activeSessionId,
        isLocal: true,
      );

      state = state.copyWith(
        messages: [...state.messages, botMessage],
        error: e.toString(),
        isTyping: false,
      );
    }
  }

  void applySuggestion(String value) {
    if (value.trim().isEmpty) return;
    state = state.copyWith(suggestions: const []);
  }

  Future<void> _streamResponse(String message, {required String locale}) async {
    final stream = _repo.streamMessage(
      message: message,
      sessionId: _activeSessionId,
      locale: locale,
    );

    bool started = false;
    String buffer = '';
    String? botId;

    await for (final event in stream) {
      switch (event.type) {
        case ChatStreamEventType.meta:
          final sessionId = event.sessionId;
          if (sessionId != null && sessionId.isNotEmpty) {
            _activeSessionId = sessionId;
          }
          break;
        case ChatStreamEventType.delta:
          final delta = event.text ?? '';
          if (delta.isEmpty) break;

          buffer += delta;

          if (!started) {
            started = true;
            botId = 'bot-${DateTime.now().microsecondsSinceEpoch}';
            final botMessage = ChatMessage(
              id: botId!,
              message: buffer,
              type: ChatMessageType.bot,
              createdAt: DateTime.now(),
              sessionId: _activeSessionId,
              isLocal: true,
            );
            state = state.copyWith(
              messages: [...state.messages, botMessage],
            );
          } else if (botId != null) {
            _updateBotMessage(botId!, buffer);
          }
          break;
        case ChatStreamEventType.done:
          final reply = event.data['reply']?.toString();
          if (!started && reply != null && reply.isNotEmpty) {
            final id = 'bot-${DateTime.now().microsecondsSinceEpoch}';
            final botMessage = ChatMessage(
              id: id,
              message: reply,
              type: ChatMessageType.bot,
              createdAt: DateTime.now(),
              sessionId: _activeSessionId,
              isLocal: true,
            );
            state = state.copyWith(
              messages: [...state.messages, botMessage],
              isTyping: false,
            );
          }

          state = state.copyWith(
            suggestions: event.suggestions,
            isTyping: false,
          );
          break;
        case ChatStreamEventType.error:
          throw ChatRepositoryException(event.data['error']?.toString() ?? 'Stream error');
      }
    }

    state = state.copyWith(isTyping: false);
  }

  void _updateBotMessage(String id, String message) {
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.id == id);
    if (index == -1) return;

    messages[index] = messages[index].copyWith(message: message);
    state = state.copyWith(messages: messages);
  }

  Future<void> resetChat({String? userName}) async {
    _activeSessionId = null;
    state = state.copyWith(
      messages: [_greetingMessage(userName)],
      suggestions: _defaultSuggestions(),
      error: null,
    );
  }

  void close() {
    final sessionId = _activeSessionId;
    if (sessionId != null) {
      unawaited(_repo.endSession(sessionId, messageCount: state.messages.length));
    }
  }

  ChatMessage _greetingMessage(String? userName) {
    final name = (userName ?? '').trim();
    final label = name.isEmpty ? 'arkadasim' : name;
    return ChatMessage(
      id: 'greeting',
      message:
          'Merhaba $label! Ben senin kariyer asistaninim. Staj, bolum secimi, CV hazirlama ve mulakat konularinda yardimci olabilirim. Sana nasil destek olayim?',
      type: ChatMessageType.bot,
      createdAt: DateTime.now(),
      sessionId: _activeSessionId,
      isLocal: true,
    );
  }

  List<String> _defaultSuggestions() {
    return const [
      'Staj basvurusu nasil yapilir?',
      'CV hazirlama ipuclari',
      'Mulakat sorulari ve cevaplari',
      'Bolum secimi icin oneriler',
    ];
  }
}
