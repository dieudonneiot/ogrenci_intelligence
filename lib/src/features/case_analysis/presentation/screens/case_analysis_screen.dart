import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/case_providers.dart';
import '../../domain/case_models.dart';

class CaseAnalysisScreen extends ConsumerStatefulWidget {
  const CaseAnalysisScreen({super.key, this.embedded = false});

  /// If embedded, we render without a Scaffold/app bar.
  final bool embedded;

  @override
  ConsumerState<CaseAnalysisScreen> createState() => _CaseAnalysisScreenState();
}

class _CaseAnalysisScreenState extends ConsumerState<CaseAnalysisScreen> {
  int _index = 0;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final asyncScenarios = ref.watch(caseScenariosProvider);

    final body = asyncScenarios.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              const Text(
                'Case Analysis failed to load',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.read(caseScenariosProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No case scenarios yet.'),
            ),
          );
        }

        final clampedIndex = _index.clamp(0, items.length - 1);
        _index = clampedIndex;
        final current = items[_index];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swipe, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 10),
                      const Text(
                        'Case Analysis',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1}/${items.length}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _SwipeCard(
                      scenario: current,
                      busy: _submitting,
                      onChoice: (choice) => _handleChoice(current, choice),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _handleChoice(current, CaseChoice.left),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            current.leftText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _handleChoice(current, CaseChoice.right),
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            current.rightText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(backgroundColor: const Color(0xFFF9FAFB), body: body);
  }

  Future<void> _handleChoice(CaseScenario scenario, CaseChoice choice) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(caseScenariosProvider.notifier)
          .submitChoice(scenarioId: scenario.id, choice: choice);
      if (!mounted) return;
      setState(() {
        _index = _index + 1;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Answer saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.scenario,
    required this.onChoice,
    required this.busy,
  });

  final CaseScenario scenario;
  final ValueChanged<CaseChoice> onChoice;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(scenario.id),
      direction: busy ? DismissDirection.none : DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onChoice(CaseChoice.right);
        } else if (dir == DismissDirection.endToStart) {
          onChoice(CaseChoice.left);
        }
        return false; // we advance manually
      },
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 18),
        child: const Icon(
          Icons.arrow_forward,
          color: Color(0xFF16A34A),
          size: 36,
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E6),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.arrow_back, color: Color(0xFFBE123C), size: 36),
      ),
      child: Container(
        width: double.infinity,
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
            const Text(
              'Scenario',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              scenario.prompt,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            const Text(
              'Swipe left or right to answer.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
