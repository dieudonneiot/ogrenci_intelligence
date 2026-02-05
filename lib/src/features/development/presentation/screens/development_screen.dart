import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../case_analysis/presentation/screens/case_analysis_screen.dart';
import '../../../nano_learning/presentation/screens/nano_learning_feed.dart';

class DevelopmentScreen extends ConsumerStatefulWidget {
  const DevelopmentScreen({super.key});

  @override
  ConsumerState<DevelopmentScreen> createState() => _DevelopmentScreenState();
}

class _DevelopmentScreenState extends ConsumerState<DevelopmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Development',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.outlineVariant.withAlpha(150)),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    labelColor: cs.onSurface,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                    indicatorColor: cs.primary,
                    tabs: const [
                      Tab(text: 'Nano-Learning'),
                      Tab(text: 'Case Analysis'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      const NanoLearningFeed(),
                      const CaseAnalysisScreen(embedded: true),
                    ],
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
