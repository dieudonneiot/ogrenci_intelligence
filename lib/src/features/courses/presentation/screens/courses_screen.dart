import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../application/courses_providers.dart';
import '../../domain/course_models.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(coursesSearchProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final allCoursesAsync = ref.watch(coursesListProvider);
    final myCoursesAsync = ref.watch(myEnrolledCoursesProvider);

    // For "Enrolled" badges in ALL tab
// Real progress for enrolled courses (used in ALL tab too)
    final progressByCourseId = myCoursesAsync.maybeWhen(
      data: (list) => <String, int>{
        for (final e in list) e.course.id: e.enrollment.progress.clamp(0, 100),
      },
      orElse: () => <String, int>{},
    );
    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t(AppText.navCourses),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.t(AppText.coursesSubtitle),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search + filters container
                  _FiltersCard(
                    searchController: _search,
                    onSearchChanged: _onSearchChanged,
                    onClear: () {
                      _search.clear();
                      ref.read(coursesSearchProvider.notifier).state = '';
                      ref.read(coursesDepartmentProvider.notifier).state = null;
                      ref.read(coursesLevelProvider.notifier).state = null;
                      ref.invalidate(coursesListProvider);
                    },
                  ),

                  const SizedBox(height: 14),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      labelColor: const Color(0xFF111827),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                      indicatorColor: const Color(0xFF6D28D9),
                      tabs: [
                        Tab(text: l10n.t(AppText.commonAll)),
                        Tab(text: l10n.t(AppText.coursesMyEnrolledTab)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 720, // keeps layout stable inside SingleChildScrollView
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        // ALL COURSES
                        allCoursesAsync.when(
                          loading: () => const _LoadingBlock(),
                          error: (e, _) => _ErrorBlock(
                            title: l10n.t(AppText.coursesLoadFailedTitle),
                            message: e.toString(),
                            onRetry: () => ref.invalidate(coursesListProvider),
                          ),
                          data: (courses) {
                            if (courses.isEmpty) {
                              return _EmptyBlock(
                                icon: Icons.menu_book_outlined,
                                title: l10n.t(AppText.coursesEmptyTitle),
                                message: l10n.t(AppText.coursesEmptySubtitle),
                              );
                            }

                            // Build dynamic filter chips (departments + levels) from dataset
                            final departments = courses
                                .map((c) => (c.department ?? '').trim())
                                .where((d) => d.isNotEmpty)
                                .toSet()
                                .toList()
                              ..sort();

                            final levels = courses
                                .map((c) => (c.level ?? '').trim())
                                .where((d) => d.isNotEmpty)
                                .toSet()
                                .toList()
                              ..sort();

                            return Column(
                              children: [
                                _QuickChipsRow(
                                  departments: departments,
                                  levels: levels,
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: courses.length,
                                    itemBuilder: (_, i) {
                                      final c = courses[i];
                                      final progress = progressByCourseId[c.id]; // null if not enrolled
                                      final isEnrolled = progress != null;

                                      return _CourseCard(
                                        course: c,
                                        enrolled: isEnrolled,
                                        progress: progress,
                                        onOpen: () => context.push('/courses/${c.id}'),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        // MY ENROLLED COURSES
                        myCoursesAsync.when(
                          loading: () => const _LoadingBlock(),
                          error: (e, _) => _ErrorBlock(
                            title: l10n.t(AppText.coursesMyLoadFailedTitle),
                            message: e.toString(),
                            onRetry: () => ref.invalidate(myEnrolledCoursesProvider),
                          ),
                          data: (myCourses) {
                            if (myCourses.isEmpty) {
                              return _EmptyBlock(
                                icon: Icons.school_outlined,
                                title: l10n.t(AppText.coursesMyEmptyTitle),
                                message: l10n.t(AppText.coursesMyEmptySubtitle),
                                actionLabel: l10n.t(AppText.coursesExploreAction),
                                onAction: () => _tabs.animateTo(0),
                              );
                            }

                            return ListView.builder(
                              itemCount: myCourses.length,
                              itemBuilder: (_, i) {
                                final item = myCourses[i];
                                return _EnrolledCourseCard(
                                  item: item,
                                  onOpen: () => context.push('/courses/${item.course.id}'),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
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

/* ---------------------------- Widgets ---------------------------- */

class _FiltersCard extends ConsumerWidget {
  const _FiltersCard({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dept = ref.watch(coursesDepartmentProvider);
    final level = ref.watch(coursesLevelProvider);
    final search = ref.watch(coursesSearchProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.t(AppText.coursesSearchHint),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              suffixIcon: (search.isNotEmpty || dept != null || level != null)
                  ? IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                      tooltip: l10n.t(AppText.commonClear),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SmallPill(
                icon: Icons.filter_alt_outlined,
                text: dept == null ? l10n.t(AppText.coursesDepartmentAll) : l10n.coursesDepartmentSelected(dept),
              ),
              _SmallPill(
                icon: Icons.bar_chart_outlined,
                text: level == null ? l10n.t(AppText.coursesLevelAll) : l10n.coursesLevelSelected(level),
              ),
              TextButton.icon(
                onPressed: () => context.go(Routes.pointsSystem),
                icon: const Icon(Icons.track_changes_outlined),
                label: Text(l10n.t(AppText.pointsSystem)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickChipsRow extends ConsumerWidget {
  const _QuickChipsRow({
    required this.departments,
    required this.levels,
  });

  final List<String> departments;
  final List<String> levels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedDept = ref.watch(coursesDepartmentProvider);
    final selectedLevel = ref.watch(coursesLevelProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(l10n.t(AppText.coursesQuickFilterLabel), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),

        // Departments
        ...departments.take(6).map((d) {
          final selected = selectedDept == d;
          return FilterChip(
            selected: selected,
            label: Text(d),
            onSelected: (_) {
              ref.read(coursesDepartmentProvider.notifier).state = selected ? null : d;
              ref.invalidate(coursesListProvider);
            },
          );
        }),

        // Levels
        ...levels.take(4).map((l) {
          final selected = selectedLevel == l;
          return FilterChip(
            selected: selected,
            label: Text(l),
            onSelected: (_) {
              ref.read(coursesLevelProvider.notifier).state = selected ? null : l;
              ref.invalidate(coursesListProvider);
            },
          );
        }),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.enrolled,
    required this.onOpen,
    this.progress,
  });

  final Course course;
  final bool enrolled;
  final int? progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = (progress ?? 0).clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.menu_book_outlined, color: Color(0xFF6D28D9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    if (enrolled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.t(AppText.coursesEnrolledPill),
                          style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (course.description ?? l10n.t(AppText.commonNoDescription)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(icon: Icons.school_outlined, text: course.department ?? '—'),
                    _MetaChip(icon: Icons.bar_chart_outlined, text: course.level ?? '—'),
                    _MetaChip(icon: Icons.access_time, text: course.duration ?? '—'),
                  ],
                ),
                if (enrolled) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: p / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dashboardCourseProgress(p),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              (enrolled && p < 100)
                  ? l10n.t(AppText.commonContinueArrow)
                  : l10n.t(AppText.commonViewDetailsArrow),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrolledCourseCard extends StatelessWidget {
  const _EnrolledCourseCard({required this.item, required this.onOpen});

  final EnrolledCourse item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = item.course;
    final p = item.enrollment.progress.clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              TextButton(onPressed: onOpen, child: Text(l10n.t(AppText.commonOpenArrow))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.description ?? l10n.t(AppText.commonNoDescription),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.dashboardCourseProgress(p),
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {

    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: const Color(0xFFD1D5DB)),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(onPressed: onAction, child: Text('$actionLabel →')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: onRetry, child: Text(l10n.t(AppText.retry))),
            ],
          ),
        ),
      ),
    );
  }
}

