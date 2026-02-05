// lib/src/features/chat/domain/chat_models.dart

enum ChatMessageType { user, bot }

ChatMessageType chatMessageTypeFromString(String value) {
  switch (value) {
    case 'user':
      return ChatMessageType.user;
    case 'bot':
      return ChatMessageType.bot;
    default:
      return ChatMessageType.bot;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.sessionId,
    this.isLocal = false,
  });

  final String id;
  final String message;
  final ChatMessageType type;
  final DateTime createdAt;
  final String? sessionId;
  final bool isLocal;

  bool get isUser => type == ChatMessageType.user;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] ?? '').toString();
    final createdRaw = map['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.now();

    return ChatMessage(
      id: (map['id'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      type: chatMessageTypeFromString(typeStr),
      createdAt: createdAt,
      sessionId: map['session_id']?.toString(),
    );
  }

  ChatMessage copyWith({
    String? id,
    String? message,
    ChatMessageType? type,
    DateTime? createdAt,
    String? sessionId,
    bool? isLocal,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      sessionId: sessionId ?? this.sessionId,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

class ChatAiResponse {
  const ChatAiResponse({
    required this.sessionId,
    required this.reply,
    required this.suggestions,
  });

  final String? sessionId;
  final String reply;
  final List<String> suggestions;

  factory ChatAiResponse.fromMap(Map<String, dynamic> map) {
    final rawSuggestions = map['suggestions'];
    final suggestions = <String>[];
    if (rawSuggestions is List) {
      for (final item in rawSuggestions) {
        if (item is String && item.trim().isNotEmpty) {
          suggestions.add(item.trim());
        }
      }
    }

    return ChatAiResponse(
      sessionId: map['session_id']?.toString(),
      reply: (map['reply'] ?? '').toString(),
      suggestions: suggestions,
    );
  }
}

enum ChatStreamEventType { meta, delta, done, error }

class ChatStreamEvent {
  const ChatStreamEvent({required this.type, required this.data});

  final ChatStreamEventType type;
  final Map<String, dynamic> data;

  String? get text => data['text']?.toString();
  String? get sessionId => data['session_id']?.toString();

  List<String> get suggestions {
    final raw = data['suggestions'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }
}
