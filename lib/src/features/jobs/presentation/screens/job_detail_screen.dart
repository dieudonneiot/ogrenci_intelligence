import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/jobs_providers.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _logged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logged) return;
    _logged = true;

    // best-effort view log (analytics)
    Future.microtask(() async {
      try {
        final repo = ref.read(jobsRepositoryProvider);
        final uid = ref.read(authViewStateProvider).value?.user?.id;
        await repo.logView(userId: uid, jobId: widget.jobId);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncVm = ref.watch(jobDetailProvider(widget.jobId));

    return Container(
      color: const Color(0xFFF9FAFB),
      child: asyncVm.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 52, color: Color(0xFFEF4444)),
                const SizedBox(height: 10),
                const Text('İlan yüklenemedi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => ref.read(jobDetailProvider(widget.jobId).notifier).refresh(),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
        data: (vm) {
          final j = vm.job;

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderCard(
                        title: j.title,
                        company: j.company,
                        location: j.location ?? '',
                        workType: j.workType ?? '',
                        remote: j.isRemote,
                        favorited: vm.isFavorited,
                        applied: vm.hasApplied,
                        onToggleFav: () async {
                          try {
                            await ref.read(jobDetailProvider(widget.jobId).notifier).toggleFavorite();
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Favori güncellenemedi')),
                            );
                          }
                        },
                        onApply: vm.hasApplied
                            ? null
                            : () => _openApply(context),
                      ),

                      const SizedBox(height: 14),

                      _Section(
                        title: 'Açıklama',
                        body: (j.description ?? '').trim().isEmpty ? 'Açıklama eklenmemiş.' : j.description!.trim(),
                      ),
                      const SizedBox(height: 12),

                      _Section(
                        title: 'Gereksinimler',
                        body: (j.requirements ?? '').trim().isEmpty ? 'Belirtilmemiş.' : j.requirements!.trim(),
                      ),
                      const SizedBox(height: 12),

                      _Section(
                        title: 'Avantajlar',
                        body: (j.benefits ?? '').trim().isEmpty ? 'Belirtilmemiş.' : j.benefits!.trim(),
                      ),

                      const SizedBox(height: 14),

                      _MetaCard(
                        salary: j.salary,
                        deadline: j.deadline,
                        views: j.viewsCount,
                        applications: j.applicationCount,
                        contactEmail: j.contactEmail,
                        onCopyEmail: (email) async {
                          await Clipboard.setData(ClipboardData(text: email));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('E-posta kopyalandı')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openApply(BuildContext context) async {
    final cover = TextEditingController();
    final cv = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Başvuru', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cover,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Cover letter (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cv,
                decoration: const InputDecoration(
                  labelText: 'CV URL (opsiyonel)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(jobDetailProvider(widget.jobId).notifier).apply(
                            coverLetter: cover.text,
                            cvUrl: cv.text,
                          );
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Başvuru gönderildi ✅')),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Başvuru gönderilemedi')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Başvur'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ---------------- UI ---------------- */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.company,
    required this.location,
    required this.workType,
    required this.remote,
    required this.favorited,
    required this.applied,
    required this.onToggleFav,
    required this.onApply,
  });

  final String title;
  final String company;
  final String location;
  final String workType;
  final bool remote;
  final bool favorited;
  final bool applied;
  final VoidCallback onToggleFav;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              IconButton(
                onPressed: onToggleFav,
                icon: Icon(
                  favorited ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(company, style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(remote ? 'Remote' : 'On-site'),
              if (workType.trim().isNotEmpty) _pill(workType.trim()),
              if (location.trim().isNotEmpty) _pill(location.trim()),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: Icon(applied ? Icons.check_circle : Icons.send),
              label: Text(applied ? 'Başvuruldu' : 'Başvur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: applied ? const Color(0xFF16A34A) : Colors.white,
                foregroundColor: applied ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.salary,
    required this.deadline,
    required this.views,
    required this.applications,
    required this.contactEmail,
    required this.onCopyEmail,
  });

  final String? salary;
  final DateTime? deadline;
  final int views;
  final int applications;
  final String? contactEmail;
  final Future<void> Function(String email) onCopyEmail;

  @override
  Widget build(BuildContext context) {
    final dl = deadline == null
        ? '—'
        : '${deadline!.day.toString().padLeft(2, '0')}.${deadline!.month.toString().padLeft(2, '0')}.${deadline!.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detaylar', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _kv('Maaş', (salary ?? '').trim().isEmpty ? '—' : salary!.trim()),
          _kv('Son başvuru', dl),
          _kv('Görüntülenme', '$views'),
          _kv('Başvuru', '$applications'),
          if ((contactEmail ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _kv('İletişim', contactEmail!.trim()),
                ),
                IconButton(
                  onPressed: () => onCopyEmail(contactEmail!.trim()),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Kopyala',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
