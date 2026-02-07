import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/nano_learning_providers.dart';
import '../../data/nano_learning_repository.dart';
import '../../domain/nano_learning_models.dart';

class NanoLearningFeed extends ConsumerStatefulWidget {
  const NanoLearningFeed({super.key});

  @override
  ConsumerState<NanoLearningFeed> createState() => _NanoLearningFeedState();
}

class _NanoLearningFeedState extends ConsumerState<NanoLearningFeed> {
  final PageController _page = PageController();
  int _active = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authViewStateProvider).valueOrNull;
    final user = auth?.user;

    if (auth?.isAuthenticated != true || user == null) {
      return Center(child: Text(l10n.t(AppText.commonPleaseSignIn)));
    }

    final feedAsync = ref.watch(nanoLearningFeedProvider);
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        text: e.toString(),
        onRetry: () => ref.invalidate(nanoLearningFeedProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2E1065),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withAlpha(160),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: PageView.builder(
              controller: _page,
              scrollDirection: Axis.vertical,
              onPageChanged: (i) => setState(() => _active = i),
              itemCount: items.length,
              itemBuilder: (_, i) {
                return _NanoVideoPage(
                  course: items[i],
                  isActive: i == _active,
                  userId: user.id,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _NanoVideoPage extends ConsumerStatefulWidget {
  const _NanoVideoPage({
    required this.course,
    required this.isActive,
    required this.userId,
  });

  final NanoVideoCourse course;
  final bool isActive;
  final String userId;

  @override
  ConsumerState<_NanoVideoPage> createState() => _NanoVideoPageState();
}

class _NanoVideoPageState extends ConsumerState<_NanoVideoPage> {
  VideoPlayerController? _controller;
  Timer? _tick;

  bool _ready = false;
  bool _error = false;
  bool _quizUnlocked = false;
  int _lastProgressSent = -1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _NanoVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.id != widget.course.id) {
      _disposeController();
      _quizUnlocked = false;
      _lastProgressSent = -1;
      _init();
      return;
    }

    if (oldWidget.isActive != widget.isActive && _controller != null) {
      if (widget.isActive) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  Future<void> _init() async {
    final url = widget.course.videoUrl.trim();
    if (url.isEmpty) {
      setState(() => _error = true);
      return;
    }

    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      setState(() {
        _ready = true;
        _error = false;
      });

      if (widget.isActive) {
        unawaited(ctrl.play());
      }

      _tick = Timer.periodic(
        const Duration(milliseconds: 650),
        (_) => _onTick(),
      );
    } catch (_) {
      setState(() => _error = true);
    }
  }

  Future<void> _onTick() async {
    final ctrl = _controller;
    if (ctrl == null || !_ready) return;

    final v = ctrl.value;
    if (!v.isInitialized) return;

    final d = v.duration.inMilliseconds;
    final p = v.position.inMilliseconds;
    if (d <= 0) return;

    final ratio = (p / d).clamp(0.0, 1.0);
    if (!_quizUnlocked && ratio >= 0.80) {
      setState(() => _quizUnlocked = true);
    }

    // Update progress occasionally (0..100) so courses/profiles reflect learning.
    final progress = (ratio * 100).round().clamp(0, 100);
    if ((progress - _lastProgressSent).abs() >= 15 || progress == 100) {
      _lastProgressSent = progress;
      try {
        await ref
            .read(nanoLearningRepositoryProvider)
            .upsertProgress(
              userId: widget.userId,
              courseId: widget.course.id,
              progress: progress,
            );
      } catch (_) {
        // Keep UI smooth; ignore occasional progress write failures.
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _tick?.cancel();
    _tick = null;
    final c = _controller;
    _controller = null;
    c?.dispose();
  }

  Future<void> _openQuiz() async {
    final questionAsync = await ref.read(
      nanoQuizQuestionProvider(widget.course.id).future,
    );
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final q = questionAsync;
    if (q == null || q.options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.nanoNoQuizConfigured))),
      );
      return;
    }

    final repo = ref.read(nanoLearningRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _NanoQuizSheet(
        course: widget.course,
        question: q,
        repo: repo,
        onSuccess: () {
          ref.invalidate(nanoLearningFeedProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final ctrl = _controller;

    final top = Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              if (course.department != null &&
                  course.department!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    course.department!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final right = Positioned(
      right: 12,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _SideButton(
              icon: (ctrl?.value.isPlaying ?? false)
                  ? Icons.pause
                  : Icons.play_arrow,
              label: (ctrl?.value.isPlaying ?? false) ? 'Pause' : 'Play',
              onTap: () {
                final c = _controller;
                if (c == null) return;
                if (c.value.isPlaying) {
                  c.pause();
                } else {
                  c.play();
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            _SideButton(
              icon: Icons.quiz_outlined,
              label: _quizUnlocked ? 'Mini quiz' : 'Mini quiz',
              accent: _quizUnlocked
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF64748B),
              onTap: _quizUnlocked ? _openQuiz : null,
            ),
            const SizedBox(height: 10),
            _SideButton(
              icon: Icons.open_in_new,
              label: 'Open',
              onTap: () async {
                final uri = Uri.tryParse(course.videoUrl);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );

    final content = _error
        ? _VideoFallback(url: course.videoUrl)
        : (_ready && ctrl != null)
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          )
        : const Center(child: CircularProgressIndicator(color: Colors.white));

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        top,
        right,
        Positioned(
          left: 12,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: _SwipeHint(isActive: widget.isActive),
          ),
        ),
      ],
    );
  }
}

class _NanoQuizSheet extends StatefulWidget {
  const _NanoQuizSheet({
    required this.course,
    required this.question,
    required this.repo,
    required this.onSuccess,
  });

  final NanoVideoCourse course;
  final NanoQuizQuestion question;
  final NanoLearningRepository repo;
  final VoidCallback onSuccess;

  @override
  State<_NanoQuizSheet> createState() => _NanoQuizSheetState();
}

class _NanoQuizSheetState extends State<_NanoQuizSheet> {
  int? _selected;
  bool _submitting = false;
  String? _result;

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() {
      _submitting = true;
      _result = null;
    });

    try {
      final res = await widget.repo.submitQuizAttempt(
        courseId: widget.course.id,
        questionId: widget.question.id,
        selectedIndex: _selected!,
        points: 10,
      );

      if (!mounted) return;
      setState(() {
        _result = res.isCorrect
            ? (res.pointsAwarded > 0
                  ? 'Correct! +${res.pointsAwarded} points'
                  : 'Correct! (already counted)')
            : 'Not correct. Try next video.';
      });
      if (res.isCorrect) widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mini quiz',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(q.question, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (int i = 0; i < q.options.length; i++)
            _OptionTile(
              label: q.options[i],
              selected: _selected == i,
              enabled: !_submitting,
              onTap: () => setState(() => _selected = i),
            ),
          if (_result != null) ...[
            const SizedBox(height: 6),
            Text(
              _result!,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: (_result!.toLowerCase().startsWith('correct'))
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting || _selected == null ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0);
    final bg = selected ? const Color(0xFFF5F3FF) : Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 2),
                  color: selected
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = accent ?? Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.swap_vert, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Swipe',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E1065),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_disabled_outlined,
                  size: 46,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Video could not be played here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(url);
                      if (uri == null) return;
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text(
                      'Open video',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          l10n.t(AppText.nanoEmptyState),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 44),
            const SizedBox(height: 10),
            Text(
              l10n.t(AppText.nanoFeedLoadFailedTitle),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.t(AppText.retry)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
