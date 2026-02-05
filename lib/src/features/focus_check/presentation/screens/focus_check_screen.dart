import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/focus_providers.dart';
import '../../domain/focus_models.dart';

class FocusCheckScreen extends ConsumerStatefulWidget {
  const FocusCheckScreen({super.key, this.focusCheckId});

  final String? focusCheckId;

  @override
  ConsumerState<FocusCheckScreen> createState() => _FocusCheckScreenState();
}

class _FocusCheckScreenState extends ConsumerState<FocusCheckScreen> {
  AcceptedInternshipApplication? _selected;
  bool _starting = false;
  bool _submitting = false;
  bool _loadingPush = false;
  String? _pushError;

  Timer? _timer;
  int _secondsLeft = 0;
  final _answerCtrl = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoadPushFocusCheck();
  }

  Future<void> _maybeLoadPushFocusCheck() async {
    final id = widget.focusCheckId?.trim();
    if (id == null || id.isEmpty) return;
    if (_loadingPush) return;

    final current = ref.read(focusSessionProvider);
    if (current != null && current.id == id) {
      _startTimer(current);
      return;
    }

    setState(() {
      _loadingPush = true;
      _pushError = null;
    });

    try {
      final repo = ref.read(focusRepositoryProvider);
      final session = await repo.fetchFocusCheckById(focusCheckId: id);
      await repo.markSentFocusCheckStarted(focusCheckId: id);
      if (!mounted) return;
      ref.read(focusSessionProvider.notifier).state = session;
      _startTimer(session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pushError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingPush = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncInternships = ref.watch(acceptedInternshipsProvider);
    final session = ref.watch(focusSessionProvider);
    final isPush = (widget.focusCheckId ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFF6D28D9)),
                    const SizedBox(width: 10),
                    const Text(
                      'Instant Focus Check',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => ref
                          .read(acceptedInternshipsProvider.notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (!isPush)
                  asyncInternships.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => _Banner(
                      color: const Color(0xFFEF4444),
                      bg: const Color(0xFFFFF1F2),
                      text: 'Failed to load internships: $e',
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const _Banner(
                          color: Color(0xFFB45309),
                          bg: Color(0xFFFFF7ED),
                          text:
                              'No accepted internship found. Focus checks are available after you are accepted.',
                        );
                      }
                      _selected ??= items.first;
                      return _InternshipPicker(
                        items: items,
                        value: _selected!,
                        onChanged: (v) => setState(() => _selected = v),
                      );
                    },
                  )
                else if (_loadingPush)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else if (_pushError != null)
                  _Banner(
                    color: const Color(0xFFEF4444),
                    bg: const Color(0xFFFFF1F2),
                    text: 'Failed to load focus check: $_pushError',
                  )
                else
                  const _Banner(
                    color: Color(0xFF2563EB),
                    bg: Color(0xFFDBEAFE),
                    text:
                        'You have a new Focus Check. Answer before time runs out.',
                  ),

                const SizedBox(height: 14),

                if (session == null)
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isPush || _starting || _selected == null)
                          ? null
                          : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_starting ? 'Starting...' : 'Start (30s)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _SessionCard(
                      session: session,
                      secondsLeft: _secondsLeft,
                      controller: _answerCtrl,
                      submitting: _submitting,
                      onSubmit: _submit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    final internship = _selected;
    if (internship == null) return;
    setState(() => _starting = true);
    try {
      final session = await ref
          .read(focusActionProvider)
          .start(internshipApplicationId: internship.applicationId);
      if (!mounted) return;
      _startTimer(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start: $e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startTimer(FocusCheckSession session) {
    _timer?.cancel();
    final now = DateTime.now().toUtc();
    final diff = session.expiresAt.difference(now);
    _secondsLeft = diff.inSeconds.clamp(0, 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft = (_secondsLeft - 1).clamp(0, 999);
      });
      if (_secondsLeft <= 0) {
        t.cancel();
      }
    });
  }

  Future<void> _submit() async {
    final session = ref.read(focusSessionProvider);
    if (session == null) return;
    if (_secondsLeft <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Time is up.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(focusActionProvider)
          .submit(focusCheckId: session.id, answer: _answerCtrl.text.trim());
      _answerCtrl.clear();
      _timer?.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _InternshipPicker extends StatelessWidget {
  const _InternshipPicker({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<AcceptedInternshipApplication> items;
  final AcceptedInternshipApplication value;
  final ValueChanged<AcceptedInternshipApplication> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AcceptedInternshipApplication>(
          isExpanded: true,
          value: value,
          items: [
            for (final it in items)
              DropdownMenuItem(
                value: it,
                child: Text(
                  '${it.companyName} — ${it.internshipTitle}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.secondsLeft,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final FocusCheckSession session;
  final int secondsLeft;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final danger = secondsLeft <= 8;
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '$secondsLeft s',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              const Text(
                'Answer before time runs out.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            session.question,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Type your answer…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (submitting || secondsLeft <= 0) ? null : onSubmit,
              icon: const Icon(Icons.send_outlined),
              label: Text(submitting ? 'Submitting...' : 'Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.bg, required this.text});

  final Color color;
  final Color bg;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
