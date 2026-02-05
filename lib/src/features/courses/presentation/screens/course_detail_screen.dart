import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/courses_providers.dart';
import '../../domain/course_models.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final enrollmentAsync = ref.watch(myCourseEnrollmentProvider(courseId));
    final repo = ref.read(coursesRepositoryProvider);

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: courseAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
                error: (e, _) => _DetailError(
                  e.toString(),
                  onRetry: () {
                    ref.invalidate(courseDetailProvider(courseId));
                    ref.invalidate(myCourseEnrollmentProvider(courseId));
                  },
                ),
                data: (course) {
                  return enrollmentAsync.when(
                    loading: () => _CourseDetailBody(
                      course: course,
                      enrollment: null,
                      enrolling: true,
                      onEnroll: null,
                      onUnenroll: null,
                      onUpdateProgress: null,
                    ),
                    error: (e, _) => _CourseDetailBody(
                      course: course,
                      enrollment: null,
                      enrolling: false,
                      onEnroll: null,
                      onUnenroll: null,
                      onUpdateProgress: null,
                      warning: l10n.coursesEnrollmentLoadFailed(e.toString()),
                    ),
                    data: (enrollment) {
                      Future<void> doEnroll() async {
                        final auth = ref.read(authViewStateProvider).value;
                        final uid = auth?.user?.id;
                        if (uid == null || uid.isEmpty) return;

                        await repo.enroll(userId: uid, courseId: courseId);

                        ref.invalidate(myEnrolledCoursesProvider);
                        ref.invalidate(myCourseEnrollmentProvider(courseId));
                      }

                      Future<void> doUnenroll() async {
                        final auth = ref.read(authViewStateProvider).value;
                        final uid = auth?.user?.id;
                        if (uid == null || uid.isEmpty) return;

                        await repo.unenroll(userId: uid, courseId: courseId);

                        ref.invalidate(myEnrolledCoursesProvider);
                        ref.invalidate(myCourseEnrollmentProvider(courseId));
                      }

                      Future<void> doUpdateProgress(int p) async {
                        if (enrollment == null) return;
                        await repo.updateProgress(
                          enrollmentId: enrollment.id,
                          progress: p,
                        );
                        ref.invalidate(myEnrolledCoursesProvider);
                        ref.invalidate(myCourseEnrollmentProvider(courseId));
                      }

                      return _CourseDetailBody(
                        course: course,
                        enrollment: enrollment,
                        enrolling: false,
                        onEnroll: doEnroll,
                        onUnenroll: enrollment == null ? null : doUnenroll,
                        onUpdateProgress: enrollment == null
                            ? null
                            : doUpdateProgress,
                      );
                    },
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

class _CourseDetailBody extends StatelessWidget {
  const _CourseDetailBody({
    required this.course,
    required this.enrollment,
    required this.enrolling,
    required this.onEnroll,
    required this.onUnenroll,
    required this.onUpdateProgress,
    this.warning,
  });

  final Course course;
  final CourseEnrollment? enrollment;
  final bool enrolling;

  final Future<void> Function()? onEnroll;
  final Future<void> Function()? onUnenroll;
  final Future<void> Function(int p)? onUpdateProgress;

  final String? warning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enrolled = enrollment != null;
    final progress = (enrollment?.progress ?? 0).clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple back row (Navbar exists already, but this helps mobile)
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.t(AppText.commonBack),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.t(AppText.courseDetailTitle),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (warning != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: Text(warning!, style: const TextStyle(color: Colors.orange)),
          ),
          const SizedBox(height: 12),
        ],

        Container(
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
              Text(
                course.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Meta(Icons.school_outlined, course.department ?? '—'),
                  _Meta(Icons.bar_chart_outlined, course.level ?? '—'),
                  _Meta(Icons.access_time, course.duration ?? '—'),
                  _Meta(Icons.person_outline, course.instructor ?? '—'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course.description ?? l10n.t(AppText.commonNoDescription),
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),

              if (course.videoUrl != null &&
                  course.videoUrl!.trim().isNotEmpty) ...[
                Text(
                  l10n.t(AppText.courseDetailVideoUrl),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  course.videoUrl!,
                  style: const TextStyle(color: Color(0xFF6D28D9)),
                ),
                const SizedBox(height: 12),
              ],

              Container(height: 1, color: const Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              if (!enrolled) ...[
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: (enrolling || onEnroll == null)
                        ? null
                        : () async => onEnroll!(),
                    icon: const Icon(Icons.add),
                    label: Text(
                      enrolling
                          ? l10n.t(AppText.commonLoading)
                          : l10n.t(AppText.courseDetailEnroll),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
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
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t(AppText.courseDetailProgress),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.dashboardCourseProgress(progress),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (onUnenroll != null)
                      OutlinedButton(
                        onPressed: () async => onUnenroll!(),
                        child: Text(l10n.t(AppText.courseDetailUnenroll)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (onUpdateProgress != null)
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: () async => onUpdateProgress!(progress + 10),
                        child: const Text('+10%'),
                      ),
                      OutlinedButton(
                        onPressed: () async => onUpdateProgress!(progress + 25),
                        child: const Text('+25%'),
                      ),
                      OutlinedButton(
                        onPressed: () async => onUpdateProgress!(100),
                        child: Text(l10n.t(AppText.profileCourseCompleted)),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError(this.message, {required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 54),
            const SizedBox(height: 10),
            Text(
              l10n.t(AppText.courseDetailLoadFailedTitle),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(l10n.t(AppText.retry)),
            ),
          ],
        ),
      ),
    );
  }
}
