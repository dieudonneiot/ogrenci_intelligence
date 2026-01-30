
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../shared/widgets/app_navbar.dart';
import '../../domain/dashboard_application.dart';
import '../controllers/student_dashboard_controller.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentDashboardProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppNavbar(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () => ref.read(studentDashboardProvider.notifier).refresh(),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () => ref.read(studentDashboardProvider.notifier).refresh(),
                child: _DashboardBody(data: data),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final StudentDashboardData data;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 980;

    final name = data.profile.fullName.trim().isNotEmpty ? data.profile.fullName.trim() : 'Kullanıcı';
    final firstName = name.split(' ').first;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $firstName 👋',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${data.profile.department} • Year ${data.profile.year}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (isWide)
                      _PillButton(
                        label: 'View Profile',
                        icon: Icons.person_outline,
                        onTap: () => context.go(Routes.profile),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Stats grid
                _ResponsiveGrid(
                  isWide: isWide,
                  children: [
                    _StatCard(
                      title: 'Total Points',
                      value: '${data.profile.totalPoints}',
                      icon: Icons.emoji_events_outlined,
                      onTap: () => context.go(Routes.pointsSystem),
                    ),
                    _StatCard(
                      title: 'Courses Completed',
                      value: '${data.completedCourses}',
                      icon: Icons.school_outlined,
                      onTap: () => context.go(Routes.courses),
                    ),
                    _StatCard(
                      title: 'Active Applications',
                      value: '${data.activeApplications}',
                      icon: Icons.work_outline,
                      onTap: () => context.go(Routes.applications),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Quick actions
                const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _ResponsiveGrid(
                  isWide: isWide,
                  dense: true,
                  children: [
                    _ActionCard(
                      title: 'Browse Courses',
                      subtitle: 'Start learning and earn points',
                      icon: Icons.menu_book_outlined,
                      onTap: () => context.go(Routes.courses),
                    ),
                    _ActionCard(
                      title: 'Find Jobs',
                      subtitle: 'Apply to student jobs',
                      icon: Icons.work_outline,
                      onTap: () => context.go(Routes.jobs),
                    ),
                    _ActionCard(
                      title: 'Find Internships',
                      subtitle: 'Internships matching your profile',
                      icon: Icons.badge_outlined,
                      onTap: () => context.go(Routes.internships),
                    ),
                    _ActionCard(
                      title: 'My Applications',
                      subtitle: 'Track your submissions',
                      icon: Icons.track_changes_outlined,
                      onTap: () => context.go(Routes.applications),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Enrolled courses
                Row(
                  children: [
                    const Expanded(
                      child: Text('Your Enrolled Courses',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    TextButton(
                      onPressed: () => context.go(Routes.courses),
                      child: const Text('See all'),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                if (data.enrolledCourses.isEmpty)
                  const _InfoCard(
                    icon: Icons.info_outline,
                    title: 'No enrolled courses yet',
                    subtitle: 'Go to Courses and enroll to start your learning path.',
                  )
                else
                  Column(
                    children: [
                      for (final c in data.enrolledCourses.take(4))
                        _CourseProgressCard(
                          course: c,
                          onOpen: () {
                            // Routes.courseDetail is /courses/:id
                            final path = '/courses/${c.courseId}';
                            context.go(path);
                          },
                        ),
                    ],
                  ),

                const SizedBox(height: 18),

                // Recent activities
                const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),

                if (data.recentActivities.isEmpty)
                  const _InfoCard(
                    icon: Icons.history,
                    title: 'No activity yet',
                    subtitle: 'Your recent points and actions will show up here.',
                  )
                else
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (final a in data.recentActivities)
                            _ActivityTile(item: a),
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
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, required this.isWide, this.dense = false});

  final List<Widget> children;
  final bool isWide;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        children: [
          for (final c in children) ...[
            c,
            SizedBox(height: dense ? 10 : 12),
          ]
        ],
      );
    }

    // 3 columns for stats, 2 columns for actions-like layout
    final cols = dense ? 2 : 3;
    final rows = <Row>[];

    for (var i = 0; i < children.length; i += cols) {
      final slice = children.skip(i).take(cols).toList();
      rows.add(
        Row(
          children: [
            for (var j = 0; j < slice.length; j++) ...[
              Expanded(child: slice[j]),
              if (j != slice.length - 1) SizedBox(width: dense ? 12 : 12),
            ],
            if (slice.length < cols)
              for (var k = 0; k < cols - slice.length; k++) ...[
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final r in rows) ...[
          r,
          SizedBox(height: dense ? 12 : 12),
        ]
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF6D28D9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        )),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF6D28D9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.course, required this.onOpen});

  final EnrolledCourse course;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = course.progress.clamp(0, 100);
    final v = p / 100.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(course.title,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$p%',
                        style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${course.level} • ${course.duration}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E7EB),
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

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  IconData get _icon {
    switch (item.type) {
      case 'course_completion':
        return Icons.school_outlined;
      case 'job_application':
        return Icons.work_outline;
      case 'internship_application':
        return Icons.badge_outlined;
      case 'profile_update':
        return Icons.person_outline;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = item.points;
    final date = item.createdAt;
    final dateText = (date == null)
        ? ''
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: const Color(0xFF6D28D9), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description.isNotEmpty ? item.description : item.type,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (dateText.isNotEmpty)
                  Text(dateText, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            points >= 0 ? '+$points' : '$points',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: points >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6D28D9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF6D28D9)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 38, color: Color(0xFFDC2626)),
                  const SizedBox(height: 10),
                  const Text('Dashboard failed to load', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
