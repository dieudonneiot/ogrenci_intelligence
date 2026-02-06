// lib/src/features/chat/presentation/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/chat_models.dart';
import '../controllers/chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  int _lastMessageCount = 0;
  String? _loadedForUserId;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);

    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    if (auth == null || !auth.isAuthenticated) {
      final l10n = AppLocalizations.of(context);
      return PlaceholderView(
        title: l10n.t(AppText.chatLoginRequiredTitle),
        subtitle: l10n.t(AppText.chatLoginRequiredSubtitle),
        icon: Icons.lock_outline,
      );
    }

    final user = auth.user;
    final userId = user?.id ?? '';
    if (userId.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return PlaceholderView(
        title: l10n.t(AppText.chatUserNotFoundTitle),
        subtitle: l10n.t(AppText.chatUserNotFoundSubtitle),
        icon: Icons.error_outline,
      );
    }

    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appLocaleProvider);
    final localeCode =
        (locale.countryCode == null || locale.countryCode!.isEmpty)
        ? locale.languageCode
        : '${locale.languageCode}-${locale.countryCode}';
    final greeting = l10n.chatGreeting(_displayNameFromUser(user));
    final suggestions = l10n.chatDefaultSuggestions();

    if (_loadedForUserId != userId) {
      _loadedForUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(chatControllerProvider(userId).notifier)
            .loadHistory(greetingMessage: greeting, suggestions: suggestions);
      });
    }

    final state = ref.watch(chatControllerProvider(userId));
    final controller = ref.read(chatControllerProvider(userId).notifier);

    if (_lastMessageCount != state.messages.length) {
      _lastMessageCount = state.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.surface, cs.primaryContainer.withAlpha(28)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              children: [
                _ChatHeader(
                  onReset: () => controller.resetChat(
                    greetingMessage: greeting,
                    suggestions: suggestions,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withAlpha(160),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withAlpha(14),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                            itemCount:
                                state.messages.length +
                                (_shouldShowTyping(state) ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_shouldShowTyping(state) &&
                                  index == state.messages.length) {
                                return const _TypingBubble();
                              }

                              final message = state.messages[index];
                              final isLast = index == state.messages.length - 1;
                              final showStreaming =
                                  isLast && !message.isUser && state.isTyping;
                              return _MessageBubble(
                                message: message,
                                showStreaming: showStreaming,
                              );
                            },
                          ),
                        ),
                        if (state.suggestions.isNotEmpty)
                          _SuggestionChips(
                            suggestions: state.suggestions,
                            onTap: (value) {
                              _inputCtrl.text = value;
                              _focusNode.requestFocus();
                            },
                          ),
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                () {
                                  final raw = state.error ?? '';
                                  if (raw.startsWith('history|')) {
                                    return l10n.chatHistoryLoadFailed(
                                      raw.substring('history|'.length),
                                    );
                                  }
                                  if (raw.startsWith('reply|')) {
                                    return l10n.chatReplyFailed(
                                      raw.substring('reply|'.length),
                                    );
                                  }
                                  return raw;
                                }(),
                                style: TextStyle(
                                  color: cs.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        _InputBar(
                          controller: _inputCtrl,
                          focusNode: _focusNode,
                          isTyping: state.isTyping,
                          onSend: () => _handleSend(
                            controller,
                            auth.session!,
                            localeCode,
                            l10n,
                          ),
                          onSubmit: () => _handleSend(
                            controller,
                            auth.session!,
                            localeCode,
                            l10n,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSend(
    ChatController controller,
    Session session,
    String localeCode,
    AppLocalizations l10n,
  ) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    controller.sendMessage(
      text,
      session: session,
      locale: localeCode,
      errorReplyMessage: l10n.t(AppText.chatBotUnavailable),
    );
    _inputCtrl.clear();
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  bool _shouldShowTyping(ChatState state) {
    if (!state.isTyping) return false;
    if (state.messages.isEmpty) return true;
    return state.messages.last.isUser;
  }

  String _displayNameFromUser(User? user) {
    if (user == null) return 'Kullanici';

    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] is String) {
      final name = (meta['full_name'] as String).trim();
      if (name.isNotEmpty) return name;
    }

    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Kullanici';
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withAlpha(24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.18 * 255).round()),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).t(AppText.chatHeaderTitle),
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).t(AppText.chatHeaderSubtitle),
                  style: TextStyle(
                    color: cs.onPrimary.withAlpha(220),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          LayoutBuilder(
            builder: (context, c) {
              final l10n = AppLocalizations.of(context);
              final isNarrow = c.maxWidth < 140;
              if (isNarrow) {
                return Tooltip(
                  message: l10n.t(AppText.chatNewChat),
                  child: IconButton(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surface,
                      foregroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(
                    l10n.t(AppText.chatNewChat),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.surface,
                    foregroundColor: cs.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showStreaming});

  final ChatMessage message;
  final bool showStreaming;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final time = DateFormat.Hm(
      Localizations.localeOf(context).toString(),
    ).format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withAlpha(14),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isUser ? cs.onPrimary : cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isUser
                              ? cs.onPrimary.withAlpha(190)
                              : cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showStreaming) ...[
                        const SizedBox(width: 8),
                        const _StreamingBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withAlpha(14),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _TypingDots(),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _StreamingBadge extends StatelessWidget {
  const _StreamingBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withAlpha(180)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: cs.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).t(AppText.chatTyping),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          const _StreamingDots(),
        ],
      ),
    );
  }
}

class _StreamingDots extends StatefulWidget {
  const _StreamingDots();

  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(opacityFor(phase, 0.0)),
            const SizedBox(width: 3),
            _dot(opacityFor(phase, 0.33)),
            const SizedBox(width: 3),
            _dot(opacityFor(phase, 0.66)),
          ],
        );
      },
    );
  }

  double opacityFor(double phase, double offset) {
    final value = (phase + offset) % 1.0;
    if (value < 0.5) return 0.4 + value;
    return 1.4 - value * 2;
  }

  Widget _dot(double opacity) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: opacity.clamp(0.2, 1.0),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: cs.onPrimaryContainer,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(opacityFor(phase, 0.0)),
            const SizedBox(width: 6),
            _dot(opacityFor(phase, 0.33)),
            const SizedBox(width: 6),
            _dot(opacityFor(phase, 0.66)),
          ],
        );
      },
    );
  }

  double opacityFor(double phase, double offset) {
    final value = (phase + offset) % 1.0;
    if (value < 0.5) return 0.4 + value;
    return 1.4 - value * 2;
  }

  Widget _dot(double opacity) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: opacity.clamp(0.2, 1.0),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final void Function(String value) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in suggestions)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(suggestion),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isTyping,
    required this.onSend,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isTyping;
  final VoidCallback onSend;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(160)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).t(AppText.chatInputHint),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: ElevatedButton(
              onPressed: isTyping ? null : onSend,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
