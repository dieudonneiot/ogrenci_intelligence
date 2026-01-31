import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../courses/application/courses_providers.dart';
import '../../../courses/domain/course.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _showVideo = false;
  bool _videoWatched = false;

  static const _totalModules = 5;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(coursesControllerProvider);
    final ctrl = ref.read(coursesControllerProvider.notifier);

    final course = st.courses.where((c) => c.id == widget.courseId).cast<Course?>().firstOrNull;
    if (course == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: Text('Kurs bulunamadı')),
      );
    }

    final isFav = st.favorites.contains(course.id);
    final isEnrolled = st.enrolled.contains(course.id);
    final isCompleted = st.completed.contains(course.id);
    final progress = st.progressByCourse[course.id] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth >= 980;

                  final left = _LeftColumn(
                    course: course,
                    isFavorite: isFav,
                    isEnrolled: isEnrolled,
                    isCompleted: isCompleted,
                    progress: progress,
                    showVideo: _showVideo,
                    videoWatched: _videoWatched,
                    totalModules: _totalModules,
                    onToggleFavorite: () => ctrl.toggleFavorite(course.id),
                    onCopyShare: () async {
                      await Clipboard.setData(ClipboardData(text: '/courses/${course.id}'));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link kopyalandı')),
                        );
                      }
                    },
                    onToggleVideo: () => setState(() => _showVideo = !_showVideo),
                    onVideoWatched: (v) => setState(() => _videoWatched = v),
                    onCompleteCourse: () {
                      ctrl.completeCourse(course.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kurs tamamlandı! 🎉')),
                      );
                    },
                    onCompleteModule: (idx) => ctrl.markModuleComplete(course.id, idx, totalModules: _totalModules),
                  );

                  final right = _RightCard(
                    course: course,
                    isEnrolled: isEnrolled,
                    isCompleted: isCompleted,
                    progress: progress,
                    onEnroll: () {
                      ctrl.enroll(course.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kursa kaydolundu ✅')),
                      );
                    },
                    onComplete: () {
                      ctrl.completeCourse(course.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kurs tamamlandı! 🎉')),
                      );
                    },
                  );

                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.course,
    required this.isFavorite,
    required this.isEnrolled,
    required this.isCompleted,
    required this.progress,
    required this.showVideo,
    required this.videoWatched,
    required this.totalModules,
    required this.onToggleFavorite,
    required this.onCopyShare,
    required this.onToggleVideo,
    required this.onVideoWatched,
    required this.onCompleteCourse,
    required this.onCompleteModule,
  });

  final Course course;
  final bool isFavorite;
  final bool isEnrolled;
  final bool isCompleted;
  final int progress;

  final bool showVideo;
  final bool videoWatched;
  final int totalModules;

  final VoidCallback onToggleFavorite;
  final VoidCallback onCopyShare;
  final VoidCallback onToggleVideo;
  final ValueChanged<bool> onVideoWatched;
  final VoidCallback onCompleteCourse;
  final ValueChanged<int> onCompleteModule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconPill(
                    icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                    onTap: onToggleFavorite,
                    tooltip: 'Favori',
                  ),
                  const SizedBox(width: 8),
                  _IconPill(
                    icon: Icons.share_outlined,
                    onTap: onCopyShare,
                    tooltip: 'Paylaş',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                course.description,
                style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // stats grid (like React)
              Wrap(
                runSpacing: 10,
                spacing: 10,
                children: [
                  _MiniStat(icon: Icons.access_time, label: 'Süre', value: course.duration),
                  _MiniStat(icon: Icons.people_outline, label: 'Kayıtlı', value: '${course.enrolledCount}'),
                  _MiniStat(icon: Icons.star, label: 'Puan', value: course.rating.toStringAsFixed(1)),
                  _MiniStat(icon: Icons.bar_chart, label: 'Seviye', value: course.level),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (isEnrolled) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('İlerlemeniz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    Text('$progress%', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress / 100.0,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCompleted ? 'Tebrikler! Kursu tamamladınız.' : 'Devam edin! Bir sonraki modüle geçebilirsiniz.',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Video block (UI-first; actual player later)
        if (course.videoUrl != null) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    TextButton.icon(
                      onPressed: onToggleVideo,
                      icon: Icon(showVideo ? Icons.close : Icons.play_circle_outline),
                      label: Text(showVideo ? 'Kapat' : 'Videoyu Göster'),
                    ),
                  ],
                ),
                if (!showVideo) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Video entegrasyonunu DB wiring aşamasında (YouTube iframe / player) ekleyeceğiz.',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, size: 64, color: Color(0x55FFFFFF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Video izleme durumu, gerçek player entegrasyonunda otomatik takip edilecek.',
                      style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: videoWatched,
                    onChanged: (v) => onVideoWatched(v ?? false),
                    title: const Text('Video izlendi'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: videoWatched && isEnrolled && !isCompleted ? onCompleteCourse : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Kursu Tamamla', style: TextStyle(fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modüller', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (int i = 0; i < totalModules; i++)
                _ModuleTile(
                  index: i,
                  title: 'Modül ${i + 1}',
                  isCompleted: (progress >= (((i + 1) / totalModules) * 100).round()),
                  enabled: isEnrolled && !isCompleted,
                  onComplete: () => onCompleteModule(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RightCard extends StatelessWidget {
  const _RightCard({
    required this.course,
    required this.isEnrolled,
    required this.isCompleted,
    required this.progress,
    required this.onEnroll,
    required this.onComplete,
  });

  final Course course;
  final bool isEnrolled;
  final bool isCompleted;
  final int progress;
  final VoidCallback onEnroll;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final canComplete = isEnrolled && !isCompleted && progress >= 80;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_rounded, size: 56, color: Color(0x55FFFFFF)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Ücretsiz', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${course.pointsCompletion} puan',
                  style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: !isEnrolled ? onEnroll : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                isEnrolled ? 'Kayıtlısınız' : 'Kursa Kaydol (+${course.pointsEnrollment})',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (canComplete)
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Kursu Tamamla', style: TextStyle(fontWeight: FontWeight.w900)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFD8B4FE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          if (isCompleted)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Kurs Tamamlandı ✅',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const _FeatureRow(icon: Icons.check_circle_outline, text: 'Ömür boyu erişim'),
          const SizedBox(height: 8),
          const _FeatureRow(icon: Icons.check_circle_outline, text: 'Sertifika (yakında)'),
          const SizedBox(height: 8),
          const _FeatureRow(icon: Icons.check_circle_outline, text: 'Mobil uyumlu içerik'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.index,
    required this.title,
    required this.isCompleted,
    required this.enabled,
    required this.onComplete,
  });

  final int index;
  final String title;
  final bool isCompleted;
  final bool enabled;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check : Icons.play_arrow,
              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
          if (!isCompleted)
            TextButton(
              onPressed: enabled ? onComplete : null,
              child: const Text('Tamamla'),
            )
          else
            const Text('Tamamlandı', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

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
      child: child,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
