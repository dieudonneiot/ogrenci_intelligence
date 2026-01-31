import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../courses/application/courses_providers.dart';
import '../../../courses/presentation/state/courses_controller.dart';
import '../../../courses/domain/course.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(coursesControllerProvider);
    final ctrl = ref.read(coursesControllerProvider.notifier);

    final filtered = _filterCourses(st.courses, st.query, st.category);

    final bg = const Color(0xFFF9FAFB);
    final maxW = MediaQuery.of(context).size.width >= 1100 ? 1080.0 : double.infinity;

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'Kurslar',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bölümünüz için özel kurslar ve kaynaklar. Öğren, ilerle, puan kazan.',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Search + Category
                  LayoutBuilder(
                    builder: (context, c) {
                      final isWide = c.maxWidth >= 780;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: isWide ? 3 : 0,
                            child: TextField(
                              onChanged: ctrl.setQuery,
                              decoration: InputDecoration(
                                hintText: 'Kurs ara...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                          Expanded(
                            flex: isWide ? 2 : 0,
                            child: DropdownButtonFormField<String>(
                              value: st.category,
                              items: CoursesController.categories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => ctrl.setCategory(v ?? 'Tümü'),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // Stats
                  _StatsRow(
                    total: st.courses.length,
                    enrolled: st.enrolled.length,
                    completed: st.completed.length,
                    points: st.earnedPoints,
                  ),

                  const SizedBox(height: 16),

                  if (st.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (st.error != null)
                    _ErrorBox(message: st.error!, onRetry: () => ctrl.load())
                  else if (filtered.isEmpty)
                    const _EmptyBox()
                  else
                    _CoursesGrid(courses: filtered),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Course> _filterCourses(List<Course> all, String query, String category) {
    final q = query.trim().toLowerCase();
    return all.where((c) {
      final matchesQuery = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.instructor.toLowerCase().contains(q);

      final matchesCategory = category == 'Tümü' || c.category == category;

      return matchesQuery && matchesCategory;
    }).toList();
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({
    required this.total,
    required this.enrolled,
    required this.completed,
    required this.points,
  });

  final int total;
  final int enrolled;
  final int completed;
  final int points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 980;

    final items = <Widget>[
      _StatCard(title: 'Toplam Kurs', value: '$total', icon: Icons.menu_book_outlined),
      _StatCard(title: 'Kayıtlı', value: '$enrolled', icon: Icons.school_outlined),
      _StatCard(title: 'Tamamlanan', value: '$completed', icon: Icons.verified_outlined),
      _StatCard(title: 'Kazanılan Puan', value: '$points', icon: Icons.emoji_events_outlined),
    ];

    if (isWide) {
      return Row(children: items.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: w))).toList()
        ..removeLast());
    }

    return Wrap(
      runSpacing: 12,
      spacing: 12,
      children: items.map((e) => SizedBox(width: (w - 16 * 2 - 12) / 2, child: e)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesGrid extends ConsumerWidget {
  const _CoursesGrid({required this.courses});
  final List<Course> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(coursesControllerProvider);
    final ctrl = ref.read(coursesControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 1024 ? 3 : (w >= 760 ? 2 : 1);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: courses.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: crossAxisCount == 1 ? 1.55 : 1.15,
          ),
          itemBuilder: (_, i) {
            final course = courses[i];
            final isFav = st.favorites.contains(course.id);
            final isEnrolled = st.enrolled.contains(course.id);
            final isCompleted = st.completed.contains(course.id);
            final progress = st.progressByCourse[course.id] ?? 0;

            return _CourseCard(
              course: course,
              isFavorite: isFav,
              isEnrolled: isEnrolled,
              isCompleted: isCompleted,
              progress: progress,
              onToggleFavorite: () => ctrl.toggleFavorite(course.id),
              onOpen: () => context.go('/courses/${course.id}'),
            );
          },
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.isFavorite,
    required this.isEnrolled,
    required this.isCompleted,
    required this.progress,
    required this.onToggleFavorite,
    required this.onOpen,
  });

  final Course course;
  final bool isFavorite;
  final bool isEnrolled;
  final bool isCompleted;
  final int progress;

  final VoidCallback onToggleFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final badge = isCompleted
        ? ('Tamamlandı', const Color(0xFF10B981), const Color(0xFFD1FAE5))
        : (isEnrolled && progress > 0)
            ? ('Devam Ediyor', const Color(0xFF3B82F6), const Color(0xFFDBEAFE))
            : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top image/gradient area
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.menu_book_rounded, size: 56, color: Color(0x55FFFFFF)),
                    ),
                    if (badge != null)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: badge.$3,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge.$1,
                            style: TextStyle(color: badge.$2, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Material(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onToggleFavorite,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            course.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${course.totalRatings})',
                            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          const Icon(Icons.people_outline, size: 18, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Text(
                            '${course.enrolledCount}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 18, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              course.instructor,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Kursa Git', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
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
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 44, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text('Kurs bulunamadı', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Aradığınız kriterlere uygun kurs bulunamadı.', style: TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}
