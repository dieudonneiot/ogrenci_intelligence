import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../oi/application/oi_providers.dart';
import '../../../oi/domain/oi_models.dart';
import '../../../user/data/points_service.dart';
import '../../application/student_dashboard_providers.dart';
import '../../domain/student_dashboard_models.dart';

final _didCheckBonusesProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();

  static int nextTarget(int points) {
    if (points < 100) return 100;
    if (points < 500) return 500;
    if (points < 1000) return 1000;
    if (points < 5000) return 5000;
    return 10000;
  }
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dashAsync = ref.watch(studentDashboardProvider);

    ref.listen(studentDashboardProvider, (prev, next) async {
      final did = ref.read(_didCheckBonusesProvider);
      if (did) return;

      next.whenData((_) async {
        ref.read(_didCheckBonusesProvider.notifier).state = true;

        final auth = ref.read(authViewStateProvider).value;
        final uid = auth?.user?.id;
        if (uid == null || uid.isEmpty) return;

        final result = await ref
            .read(pointsServiceProvider)
            .checkLoginBonuses(userId: uid);

        if (!context.mounted) return;

        final l10n = AppLocalizations.of(context);
        if (result.dailyAwarded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t(AppText.dashboardDailyLoginBonus))),
          );
        }
        if (result.weeklyAwarded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t(AppText.dashboardWeeklyStreakBonus))),
          );
        }

        if (result.dailyAwarded || result.weeklyAwarded) {
          await ref.read(studentDashboardProvider.notifier).refresh();
        }
      });
    });

    return dashAsync.when(
      loading: () => const _DashboardLoading(),
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
              Text(
                l10n.t(AppText.dashboardLoadFailed),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.read(studentDashboardProvider.notifier).refresh(),
                  child: Text(l10n.t(AppText.retry)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (vm) {
        final stats = vm.stats;

        return Container(
          color: const Color(0xFFF9FAFB),
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(studentDashboardProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.dashboardWelcome(vm.displayName),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.t(AppText.dashboardWelcomeSubtitle),
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _MiniOiScoreChip(
                              oiAsync: ref.watch(myOiProfileProvider),
                              onTap: () => context.go(Routes.profile),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _UrgentTaskCard(
                          tasks: vm.tasks,
                          onEvidence: () => context.go(Routes.evidence),
                          onCaseAnalysis: () => context.go(Routes.caseAnalysis),
                          onFocusCheck: () => context.go(Routes.focusCheck),
                          onProfile: () => context.go(Routes.profile),
                        ),

                        const SizedBox(height: 18),

                        LayoutBuilder(
                          builder: (_, c) {
                            final w = c.maxWidth;
                            final isWide = w >= 980;

                            final cards = <Widget>[
                              _StatCard(
                                icon: Icons.emoji_events_outlined,
                                iconBg: const Color(0xFFEDE9FE),
                                iconColor: const Color(0xFF7C3AED),
                                title: l10n.t(AppText.dashboardTotalPoints),
                                value: '${stats.totalPoints}',
                                subtitle: stats.departmentRank != null
                                    ? l10n.dashboardDepartmentRank(
                                        stats.departmentRank!,
                                      )
                                    : null,
                                showTrend: true,
                              ),
                              _StatCard(
                                icon: Icons.menu_book_outlined,
                                iconBg: const Color(0xFFDBEAFE),
                                iconColor: const Color(0xFF2563EB),
                                title: l10n.t(
                                  AppText.dashboardCompletedCourses,
                                ),
                                value: '${stats.coursesCompleted}',
                              ),
                              _StatCard(
                                icon: Icons.work_outline,
                                iconBg: const Color(0xFFDCFCE7),
                                iconColor: const Color(0xFF16A34A),
                                title: l10n.t(
                                  AppText.dashboardActiveApplications,
                                ),
                                value: '${stats.activeApplications}',
                              ),
                              _StatCard(
                                icon: Icons.event_available_outlined,
                                iconBg: const Color(0xFFFFEDD5),
                                iconColor: const Color(0xFFEA580C),
                                title: 'Days Attended (Month)',
                                value: '${stats.daysAttendedThisMonth}',
                              ),
                              _StatCard(
                                icon: Icons.swipe,
                                iconBg: const Color(0xFFE0E7FF),
                                iconColor: const Color(0xFF4338CA),
                                title: 'Cases Solved',
                                value: '${stats.casesSolved}',
                              ),
                              _StatCard(
                                icon: Icons.track_changes_outlined,
                                iconBg: const Color(0xFFFEF3C7),
                                iconColor: const Color(0xFFD97706),
                                title: l10n.t(AppText.dashboardOngoingCourses),
                                value: '${stats.ongoingCourses}',
                              ),
                            ];

                            if (isWide) {
                              return Row(
                                children: [
                                  for (int i = 0; i < cards.length; i++) ...[
                                    Expanded(child: cards[i]),
                                    if (i != cards.length - 1)
                                      const SizedBox(width: 14),
                                  ],
                                ],
                              );
                            }

                            final half = (w - 14) / 2;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: cards
                                  .map((e) => SizedBox(width: half, child: e))
                                  .toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        _MvpActionsRow(
                          onFocusCheck: () => context.go(Routes.focusCheck),
                          onCaseAnalysis: () => context.go(Routes.caseAnalysis),
                          onEvidence: () => context.go(Routes.evidence),
                          onProfile: () => context.go(Routes.profile),
                        ),

                        const SizedBox(height: 16),

                        _PointsHero(
                          totalPoints: stats.totalPoints,
                          departmentRank: stats.departmentRank,
                          onLeaderboard: () => context.go(Routes.leaderboard),
                          onHowToPoints: () => context.go(Routes.pointsSystem),
                          todayPoints: vm.todayPoints,
                          weekPoints: vm.weekPoints,
                          coursesCompleted: stats.coursesCompleted,
                          nextTarget: StudentDashboardScreen.nextTarget(
                            stats.totalPoints,
                          ),
                        ),

                        const SizedBox(height: 18),

                        _ChatAssistantCard(
                          onStartChat: () => context.go(Routes.chat),
                        ),

                        const SizedBox(height: 18),

                        _RecommendedCoursesStrip(
                          courses: vm.recommendedCourses,
                          onOpen: (id) => context.go('/courses/$id'),
                        ),

                        const SizedBox(height: 18),

                        LayoutBuilder(
                          builder: (_, c) {
                            final isWide = c.maxWidth >= 1024;

                            final left = _OngoingCoursesCard(
                              enrolledCourses: vm.enrolledCourses,
                              onSeeAll: () => context.go(Routes.courses),
                            );

                            final right = _RecentActivitiesCard(
                              activities: vm.activities,
                            );

                            if (!isWide) {
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 14),
                                  right,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: left),
                                const SizedBox(width: 16),
                                SizedBox(width: 360, child: right),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniOiScoreChip extends StatelessWidget {
  const _MiniOiScoreChip({required this.oiAsync, required this.onTap});

  final AsyncValue<OiProfile> oiAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = oiAsync.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, st) =>
          const Text('—', style: TextStyle(fontWeight: FontWeight.w900)),
      data: (profile) {
        final score = profile.oiScore;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
            const Text(
              '/100',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        );
      },
    );

    return Semantics(
      button: true,
      label: 'OI Score',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _UrgentTaskCard extends StatelessWidget {
  const _UrgentTaskCard({
    required this.tasks,
    required this.onEvidence,
    required this.onCaseAnalysis,
    required this.onFocusCheck,
    required this.onProfile,
  });

  final DashboardTaskSummary tasks;
  final VoidCallback onEvidence;
  final VoidCallback onCaseAnalysis;
  final VoidCallback onFocusCheck;
  final VoidCallback onProfile;

  _TaskUi _pickTask() {
    if (tasks.pendingEvidenceCount > 0) {
      return _TaskUi(
        icon: Icons.verified_outlined,
        iconColor: const Color(0xFF16A34A),
        title: 'Evidence submitted',
        subtitle: '${tasks.pendingEvidenceCount} item(s) pending approval',
        actionLabel: 'View evidence',
        onAction: onEvidence,
      );
    }

    if (tasks.hasAcceptedInternship) {
      return _TaskUi(
        icon: Icons.upload_file,
        iconColor: const Color(0xFF7C3AED),
        title: 'Upload your internship proof',
        subtitle: 'Submit evidence so your mentor can approve it.',
        actionLabel: 'Upload proof',
        onAction: onEvidence,
      );
    }

    if (tasks.unansweredCaseCount > 0) {
      return _TaskUi(
        icon: Icons.swipe,
        iconColor: const Color(0xFF2563EB),
        title: 'New case analysis available',
        subtitle: '${tasks.unansweredCaseCount} scenario(s) ready',
        actionLabel: 'Start now',
        onAction: onCaseAnalysis,
      );
    }

    return _TaskUi(
      icon: Icons.timer_outlined,
      iconColor: const Color(0xFFF59E0B),
      title: 'Instant Focus Check',
      subtitle: '30s challenge to boost your consistency.',
      actionLabel: 'Start',
      onAction: onFocusCheck,
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = _pickTask();

    final chips = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _TaskChip(
          icon: Icons.work_outline,
          label: tasks.hasAcceptedInternship
              ? 'Internship active'
              : 'No internship yet',
          color: tasks.hasAcceptedInternship
              ? const Color(0xFF16A34A)
              : const Color(0xFF6B7280),
        ),
        _TaskChip(
          icon: Icons.verified_outlined,
          label: tasks.pendingEvidenceCount > 0
              ? '${tasks.pendingEvidenceCount} pending proof'
              : 'No pending proof',
          color: tasks.pendingEvidenceCount > 0
              ? const Color(0xFF16A34A)
              : const Color(0xFF6B7280),
        ),
        _TaskChip(
          icon: Icons.swipe,
          label: tasks.unansweredCaseCount > 0
              ? '${tasks.unansweredCaseCount} new cases'
              : 'No new cases',
          color: tasks.unansweredCaseCount > 0
              ? const Color(0xFF2563EB)
              : const Color(0xFF6B7280),
        ),
        _TaskChip(
          icon: Icons.person_outline,
          label: 'Improve profile',
          color: const Color(0xFF7C3AED),
          onTap: onProfile,
        ),
      ],
    );

    final primaryButton = SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: picked.onAction,
        icon: Icon(picked.icon),
        label: Text(
          picked.actionLabel,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF4F46E5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, c) {
          final isWide = c.maxWidth >= 720;

          final left = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: picked.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(picked.icon, color: picked.iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      picked.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      picked.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    chips,
                  ],
                ),
              ),
            ],
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 14), primaryButton],
            );
          }

          return Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              primaryButton,
            ],
          );
        },
      ),
    );
  }
}

class _TaskUi {
  const _TaskUi({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: content,
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

class _RecommendedCoursesStrip extends StatelessWidget {
  const _RecommendedCoursesStrip({required this.courses, required this.onOpen});

  final List<DashboardRecommendedCourse> courses;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final items = courses.isEmpty
        ? List<DashboardRecommendedCourse>.generate(
            3,
            (i) => DashboardRecommendedCourse(
              id: '_placeholder_$i',
              title: '',
              department: null,
              videoUrl: null,
            ),
          )
        : courses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text(
              'Picked for you',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, i) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = items[i];
              final isPlaceholder = c.id.startsWith('_placeholder_');
              return _RecommendedCourseCard(
                course: c,
                isPlaceholder: isPlaceholder,
                onTap: isPlaceholder ? null : () => onOpen(c.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendedCourseCard extends StatelessWidget {
  const _RecommendedCourseCard({
    required this.course,
    required this.onTap,
    required this.isPlaceholder,
  });

  final DashboardRecommendedCourse course;
  final VoidCallback? onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final title = course.title.trim();
    final department = course.department?.trim();
    final hasVideo =
        (course.videoUrl != null && course.videoUrl!.trim().isNotEmpty);

    final bg = isPlaceholder
        ? const LinearGradient(colors: [Color(0xFFE5E7EB), Color(0xFFF3F4F6)])
        : const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]);

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: bg),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Theme.of(context).colorScheme.primary.withValues(
                        alpha: isPlaceholder ? 0.0 : 0.32,
                      ),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  (department == null || department.isEmpty)
                      ? 'Course'
                      : department,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasVideo
                      ? Icons.play_arrow_rounded
                      : Icons.menu_book_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                title.isEmpty ? ' ' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaceholder ? const Color(0xFFE5E7EB) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: 260,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MvpActionsRow extends StatelessWidget {
  const _MvpActionsRow({
    required this.onFocusCheck,
    required this.onCaseAnalysis,
    required this.onEvidence,
    required this.onProfile,
  });

  final VoidCallback onFocusCheck;
  final VoidCallback onCaseAnalysis;
  final VoidCallback onEvidence;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth >= 900;
        final items = <Widget>[
          _ActionCard(
            icon: Icons.timer_outlined,
            title: 'Instant Focus Check',
            subtitle: '30s timer challenge',
            color: const Color(0xFF6D28D9),
            onTap: onFocusCheck,
          ),
          _ActionCard(
            icon: Icons.swipe,
            title: 'Case Analysis',
            subtitle: 'Swipe to answer',
            color: const Color(0xFF2563EB),
            onTap: onCaseAnalysis,
          ),
          _ActionCard(
            icon: Icons.upload_file,
            title: 'Upload Evidence',
            subtitle: 'Pending approval',
            color: const Color(0xFF16A34A),
            onTap: onEvidence,
          ),
          _ActionCard(
            icon: Icons.insights_outlined,
            title: 'OI Score',
            subtitle: 'View your profile',
            color: const Color(0xFFF59E0B),
            onTap: onProfile,
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }

        final w = (c.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items.map((e) => SizedBox(width: w, child: e)).toList(),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/* ----------------------------- UI Widgets ----------------------------- */

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.showTrend = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const Spacer(),
              if (showTrend)
                const Icon(Icons.trending_up, color: Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({
    required this.totalPoints,
    required this.departmentRank,
    required this.onLeaderboard,
    required this.onHowToPoints,
    required this.todayPoints,
    required this.weekPoints,
    required this.coursesCompleted,
    required this.nextTarget,
  });

  final int totalPoints;
  final int? departmentRank;

  final VoidCallback onLeaderboard;
  final VoidCallback onHowToPoints;

  final int todayPoints;
  final int weekPoints;
  final int coursesCompleted;
  final int nextTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (_, c) {
              final isWide = c.maxWidth >= 860;

              final left = Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 56,
                    color: Color(0x88FFFFFF),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t(AppText.dashboardPointsStatusTitle),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$totalPoints',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              l10n.t(AppText.commonPoints),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (departmentRank != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.dashboardDepartmentRank(departmentRank!),
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );

              final buttons = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onLeaderboard,
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: Text(
                        l10n.t(AppText.dashboardViewLeaderboard),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF1F2937),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onHowToPoints,
                      icon: const Icon(Icons.track_changes_outlined),
                      label: Text(
                        l10n.t(AppText.dashboardHowToEarnPoints),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6D28D9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              );

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [left, const SizedBox(height: 14), buttons],
                );
              }

              return Row(
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 12),
                  buttons,
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0x44FFFFFF)),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (_, c) {
              final isWide = c.maxWidth >= 860;
              final items = <Widget>[
                _MiniMetric(
                  title: l10n.t(AppText.dashboardMetricToday),
                  value: l10n.pointsDelta(todayPoints),
                ),
                _MiniMetric(
                  title: l10n.t(AppText.dashboardMetricThisWeek),
                  value: l10n.pointsDelta(weekPoints),
                ),
                _MiniMetric(
                  title: l10n.t(AppText.dashboardMetricCoursesCompleted),
                  value: '$coursesCompleted',
                ),
                _MiniMetric(
                  title: l10n.t(AppText.dashboardMetricNextTarget),
                  value: l10n.pointsValue(nextTarget),
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      Expanded(child: items[i]),
                      if (i != items.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items
                    .map(
                      (e) => SizedBox(width: (c.maxWidth - 10) / 2, child: e),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChatAssistantCard extends StatelessWidget {
  const _ChatAssistantCard({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;

          final left = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t(AppText.dashboardAssistantTitle),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t(AppText.dashboardAssistantSubtitle),
                      style: const TextStyle(
                        color: Color(0xDDFFFFFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final bullets = Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _ChatChip(
                icon: Icons.description_outlined,
                label: l10n.t(AppText.dashboardAssistantChipCv),
              ),
              _ChatChip(
                icon: Icons.work_outline,
                label: l10n.t(AppText.dashboardAssistantChipInternships),
              ),
              _ChatChip(
                icon: Icons.mic_none,
                label: l10n.t(AppText.dashboardAssistantChipInterview),
              ),
            ],
          );

          final button = SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onStartChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(
                l10n.t(AppText.dashboardStartChat),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5B21B6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 14),
                bullets,
                const SizedBox(height: 14),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [left, const SizedBox(height: 14), bullets],
                ),
              ),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _ChatChip extends StatelessWidget {
  const _ChatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha((0.25 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OngoingCoursesCard extends StatelessWidget {
  const _OngoingCoursesCard({
    required this.enrolledCourses,
    required this.onSeeAll,
  });

  final List<DashboardEnrolledCourse> enrolledCourses;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.menu_book_outlined, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t(AppText.dashboardOngoingCoursesTitle),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: Text(l10n.t(AppText.commonSeeAllArrow)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (enrolledCourses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    const Icon(
                      Icons.menu_book,
                      size: 46,
                      color: Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.t(AppText.dashboardNoCourses),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: onSeeAll,
                      child: Text(l10n.t(AppText.dashboardExploreCoursesArrow)),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: enrolledCourses
                  .map((e) => _EnrolledCourseTile(course: e))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _EnrolledCourseTile extends StatelessWidget {
  const _EnrolledCourseTile({required this.course});
  final DashboardEnrolledCourse course;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = course.progress.clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  course.level,
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            course.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 1024;
              final isTablet = width >= 768 && width < 1024;
              final isMobile = width < 768;

              final progress = SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dashboardCourseProgress(p),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );

              final actionButton = SizedBox(
                height: isTablet ? 32 : 40,
                width: isMobile ? double.infinity : 128,
                child: ElevatedButton(
                  onPressed: () => context.go('/courses/${course.courseId}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.t(AppText.commonContinueArrow),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isTablet ? 12 : 14,
                    ),
                  ),
                ),
              );

              final row = Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    course.duration,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  progress,
                ],
              );

              if (isDesktop) return row;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row,
                  const SizedBox(height: 10),
                  if (isMobile)
                    actionButton
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: actionButton,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentActivitiesCard extends StatelessWidget {
  const _RecentActivitiesCard({required this.activities});
  final List<ActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(
                Icons.local_activity_outlined,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t(AppText.dashboardRecentActivitiesTitle),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_activity_outlined,
                      size: 42,
                      color: Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t(AppText.dashboardNoActivity),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 380, // React-like scroll area
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (_, i) => _ActivityRow(activity: activities[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = _activityStyle(activity.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(style.icon, color: style.fg, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.action,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _dateText(context, activity.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (activity.points > 0)
                      Text(
                        l10n.pointsDelta(activity.points),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateText(BuildContext context, DateTime dt) {
    return MaterialLocalizations.of(context).formatShortDate(dt);
  }

  static _ActStyle _activityStyle(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.course:
        return const _ActStyle(
          icon: Icons.menu_book_outlined,
          fg: Color(0xFF2563EB),
          bg: Color(0xFFDBEAFE),
        );
      case ActivityCategory.job:
        return const _ActStyle(
          icon: Icons.work_outline,
          fg: Color(0xFF7C3AED),
          bg: Color(0xFFEDE9FE),
        );
      case ActivityCategory.internship:
        return const _ActStyle(
          icon: Icons.business_center_outlined,
          fg: Color(0xFF16A34A),
          bg: Color(0xFFDCFCE7),
        );
      case ActivityCategory.achievement:
        return const _ActStyle(
          icon: Icons.emoji_events_outlined,
          fg: Color(0xFFD97706),
          bg: Color(0xFFFEF3C7),
        );
      case ActivityCategory.platform:
        return const _ActStyle(
          icon: Icons.bolt_outlined,
          fg: Color(0xFF4B5563),
          bg: Color(0xFFF3F4F6),
        );
    }
  }
}

class _ActStyle {
  const _ActStyle({required this.icon, required this.fg, required this.bg});
  final IconData icon;
  final Color fg;
  final Color bg;
}
