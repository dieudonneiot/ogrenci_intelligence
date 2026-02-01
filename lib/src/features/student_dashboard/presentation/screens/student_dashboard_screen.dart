import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../user/data/points_service.dart';
import '../../application/student_dashboard_providers.dart';
import '../../domain/student_dashboard_models.dart';

final _didCheckBonusesProvider = StateProvider.autoDispose<bool>((ref) => false);

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();

  static int nextTarget(int points) {
    if (points < 100) return 100;
    if (points < 500) return 500;
    if (points < 1000) return 1000;
    if (points < 5000) return 5000;
    return 10000;
  }
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(studentDashboardProvider);

    ref.listen(studentDashboardProvider, (prev, next) async {
      final did = ref.read(_didCheckBonusesProvider);
      if (did) return;

      next.whenData((_) async {
        ref.read(_didCheckBonusesProvider.notifier).state = true;

        final auth = ref.read(authViewStateProvider).value;
        final uid = auth?.user?.id;
        if (uid == null || uid.isEmpty) return;

        final result = await ref.read(pointsServiceProvider).checkLoginBonuses(userId: uid);

        if (!context.mounted) return;

        if (result.dailyAwarded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Günlük giriş bonusu kazandınız! +2 puan')),
          );
        }
        if (result.weeklyAwarded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('7 günlük seri tamamlandı! +15 puan')),
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
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Dashboard yüklenemedi',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => ref.read(studentDashboardProvider.notifier).refresh(),
                  child: const Text('Tekrar dene'),
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
            onRefresh: () => ref.read(studentDashboardProvider.notifier).refresh(),
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
                        Text(
                          'Hoş Geldin, ${vm.displayName}! 👋',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Bugün kariyerine yön verecek yeni fırsatlar seni bekliyor.',
                          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
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
                                title: 'Toplam Puan',
                                value: '${stats.totalPoints}',
                                subtitle: stats.departmentRank != null
                                    ? 'Bölüm sıralaması: ${stats.departmentRank}.'
                                    : null,
                              ),
                              _StatCard(
                                icon: Icons.menu_book_outlined,
                                iconBg: const Color(0xFFDBEAFE),
                                iconColor: const Color(0xFF2563EB),
                                title: 'Tamamlanan Kurs',
                                value: '${stats.coursesCompleted}',
                              ),
                              _StatCard(
                                icon: Icons.work_outline,
                                iconBg: const Color(0xFFDCFCE7),
                                iconColor: const Color(0xFF16A34A),
                                title: 'Aktif Başvuru',
                                value: '${stats.activeApplications}',
                              ),
                              _StatCard(
                                icon: Icons.track_changes_outlined,
                                iconBg: const Color(0xFFFEF3C7),
                                iconColor: const Color(0xFFD97706),
                                title: 'Devam Eden Kurs',
                                value: '${stats.ongoingCourses}',
                              ),
                            ];

                            if (isWide) {
                              return Row(
                                children: [
                                  for (int i = 0; i < cards.length; i++) ...[
                                    Expanded(child: cards[i]),
                                    if (i != cards.length - 1) const SizedBox(width: 14),
                                  ],
                                ],
                              );
                            }

                            final half = (w - 14) / 2;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: cards.map((e) => SizedBox(width: half, child: e)).toList(),
                            );
                          },
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
                          nextTarget: StudentDashboardScreen.nextTarget(stats.totalPoints),
                        ),

                        const SizedBox(height: 18),

                        LayoutBuilder(
                          builder: (_, c) {
                            final isWide = c.maxWidth >= 1024;

                            final left = _OngoingCoursesCard(
                              enrolledCourses: vm.enrolledCourses,
                              onSeeAll: () => context.go(Routes.courses),
                            );

                            final right = _RecentActivitiesCard(activities: vm.activities);

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
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor),
              ),
              const Spacer(),
              const Icon(Icons.trending_up, color: Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 12)),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (_, c) {
              final isWide = c.maxWidth >= 860;

              final left = Row(
                children: [
                  const Icon(Icons.emoji_events, size: 56, color: Color(0x88FFFFFF)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Puan Durumun',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$totalPoints',
                              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 6),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 5),
                            child: Text('Puan', style: TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      if (departmentRank != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Bölüm sıralaması: $departmentRank.',
                          style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w800),
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
                      label: const Text('Sıralamayı Gör', style: TextStyle(fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF111827),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onHowToPoints,
                      icon: const Icon(Icons.track_changes_outlined),
                      label: const Text('Nasıl Puan Kazanırım?', style: TextStyle(fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6D28D9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              );

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    left,
                    const SizedBox(height: 14),
                    buttons,
                  ],
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
                _MiniMetric(title: 'Bugün', value: '+$todayPoints puan'),
                _MiniMetric(title: 'Bu Hafta', value: '+$weekPoints puan'),
                _MiniMetric(title: 'Kurs Tamamlama', value: '$coursesCompleted'),
                _MiniMetric(title: 'Sonraki Hedef', value: '$nextTarget puan'),
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
                children: items.map((e) => SizedBox(width: (c.maxWidth - 10) / 2, child: e)).toList(),
              );
            },
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
          Text(title, style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Devam Eden Kurslarım', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('Tümünü Gör →')),
            ],
          ),
          const SizedBox(height: 12),

          if (enrolledCourses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    const Icon(Icons.menu_book, size: 46, color: Color(0xFFD1D5DB)),
                    const SizedBox(height: 10),
                    const Text(
                      'Henüz devam eden kursunuz yok.',
                      style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: onSeeAll, child: const Text('Kursları Keşfet →')),
                  ],
                ),
              ),
            )
          else
            Column(
              children: enrolledCourses
                  .map(
                    (e) => _EnrolledCourseTile(course: e),
                  )
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
                child: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  course.level,
                  style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            course.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                course.duration,
                style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const Spacer(),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () => context.go('/courses/${course.courseId}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Devam Et →', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),

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
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '%$p tamamlandı',
              style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12),
            ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_activity_outlined, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Son Aktiviteler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('Henüz aktivite yok.',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
              ),
            )
          else
            SizedBox(
              height: 380, // ✅ React-like scroll area
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
    final style = _activityStyle(activity.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(style.icon, color: style.fg, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.action, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(_dateText(activity.createdAt),
                        style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    if (activity.points > 0)
                      Text('+${activity.points} puan',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateText(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);

    final diffDays = today.difference(d).inDays;

    if (diffDays == 0) return 'Bugün';
    if (diffDays == 1) return 'Dün';
    if (diffDays < 7) return '$diffDays gün önce';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  static _ActStyle _activityStyle(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.course:
        return const _ActStyle(icon: Icons.menu_book_outlined, fg: Color(0xFF2563EB), bg: Color(0xFFDBEAFE));
      case ActivityCategory.job:
        return const _ActStyle(icon: Icons.work_outline, fg: Color(0xFF7C3AED), bg: Color(0xFFEDE9FE));
      case ActivityCategory.internship:
        return const _ActStyle(icon: Icons.business_center_outlined, fg: Color(0xFF16A34A), bg: Color(0xFFDCFCE7));
      case ActivityCategory.achievement:
        return const _ActStyle(icon: Icons.emoji_events_outlined, fg: Color(0xFFD97706), bg: Color(0xFFFEF3C7));
      case ActivityCategory.platform:
        return const _ActStyle(icon: Icons.bolt_outlined, fg: Color(0xFF4B5563), bg: Color(0xFFF3F4F6));
    }
  }
}

class _ActStyle {
  const _ActStyle({required this.icon, required this.fg, required this.bg});
  final IconData icon;
  final Color fg;
  final Color bg;
}
