import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/jobs_providers.dart';
import '../../domain/job_models.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVm = ref.watch(jobDetailViewProvider(jobId));

    return asyncVm.when(
      loading: () => const Scaffold(
        body: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 12),
                const Text('Ilan yuklenemedi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => ref.read(jobDetailViewProvider(jobId).notifier).refresh(),
                    child: const Text('Tekrar dene'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (vm) => _Body(vm: vm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.vm});
  final JobDetailViewModel vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = vm.job;
    final applied = vm.applicationStatus != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Is Detayi', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await ref.read(jobDetailViewProvider(j.id).notifier).toggleFavorite();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Favori guncellenemedi: $e')),
                );
              }
            },
            icon: Icon(vm.isFavorite ? Icons.favorite : Icons.favorite_border, color: const Color(0xFFEF4444)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(j.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            ),
                            if (applied) _StatusPill(status: vm.applicationStatus!),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${j.companyName} - ${j.location}',
                          style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(text: j.department, bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9)),
                            _Chip(text: j.workType, bg: const Color(0xFFF3F4F6), fg: const Color(0xFF374151)),
                            if (j.isRemote)
                              _Chip(text: 'Remote', bg: const Color(0xFFDCFCE7), fg: const Color(0xFF16A34A)),
                            if (j.deadline != null)
                              _Chip(
                                text: 'Son: ${_fmtDate(j.deadline!)}',
                                bg: const Color(0xFFFFF7ED),
                                fg: const Color(0xFFB45309),
                              ),
                            if ((j.salaryText?.trim().isNotEmpty ?? false) ||
                                (j.salaryMin ?? 0) > 0 ||
                                (j.salaryMax ?? 0) > 0)
                              _Chip(
                                text: _salaryText(j.salaryText, j.salaryMin, j.salaryMax),
                                bg: const Color(0xFFDBEAFE),
                                fg: const Color(0xFF1D4ED8),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(title: 'Aciklama', text: j.description),
                  const SizedBox(height: 12),
                  _Section(title: 'Gereksinimler', text: j.requirements),
                  const SizedBox(height: 18),
                  if (!applied)
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openApplySheet(context, ref, j.id),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Basvur', style: TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, color: Color(0xFF6D28D9)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bu ilana basvurdun. Durum: ${vm.applicationStatus}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4B5563)),
                            ),
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

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _salaryText(String? salaryText, int? min, int? max) {
    final s = (salaryText ?? '').trim();
    if (s.isNotEmpty) return s;
    final a = min ?? 0;
    final b = max ?? 0;
    if (a > 0 && b > 0) return '$a - $b';
    if (a > 0) return 'Min $a';
    if (b > 0) return 'Max $b';
    return '';
  }

  static Future<void> _openApplySheet(BuildContext context, WidgetRef ref, String jobId) async {
    final ctrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Basvuru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'Istersen kisa bir cover letter ekle (opsiyonel).',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Motivasyonun / kisa tanitimin...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(jobDetailViewProvider(jobId).notifier).apply(ctrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Basvuru gonderildi')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Basvuru gonderilemedi: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Gonder', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            text.isEmpty ? '-' : text,
            style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    Color bg;
    Color fg;
    String label;

    switch (s) {
      case 'accepted':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Kabul';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Red';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Basvuruldu';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }
}
