import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/internships_providers.dart';
import '../../domain/internship_models.dart';

class InternshipDetailScreen extends ConsumerWidget {
  const InternshipDetailScreen({super.key, required this.internshipId});

  final String internshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVm = ref.watch(internshipDetailProvider(internshipId));

    return asyncVm.when(
      loading: () => const Scaffold(
        body: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Staj Detayı')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 10),
                const Text('Detay yüklenemedi', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => ref.read(internshipDetailProvider(internshipId).notifier).refresh(),
                    child: const Text('Tekrar dene'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (vm) {
        final item = vm.item;
        final i = item.internship;
        final myStatus = item.myApplication?.status;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            title: const Text('Staj Detayı'),
            actions: [
              IconButton(
                tooltip: 'Favori',
                onPressed: () => ref.read(internshipDetailProvider(internshipId).notifier).toggleFavorite(),
                icon: Icon(item.isFavorite ? Icons.favorite : Icons.favorite_border),
                color: item.isFavorite ? const Color(0xFFEF4444) : null,
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(i.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            ),
                            if (myStatus != null) _StatusPill(status: myStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.apartment, size: 18, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(i.companyName,
                                  style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Meta(icon: Icons.location_on_outlined, text: i.location ?? 'Belirtilmemiş'),
                            _Meta(icon: Icons.schedule, text: '${i.durationMonths} ay'),
                            if (i.isRemote) const _Meta(icon: Icons.wifi, text: 'Remote'),
                            _Meta(icon: Icons.paid_outlined, text: i.isPaid ? 'Ücretli' : 'Ücretsiz'),
                            if (i.deadline != null)
                              _Meta(icon: Icons.event_outlined, text: 'Son: ${_fmtDate(i.deadline!)}'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Açıklama', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          i.description.isNotEmpty ? i.description : 'Açıklama yok.',
                          style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  if (i.requirements.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gereksinimler', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 8),
                          for (final r in i.requirements) _Bullet(r),
                        ],
                      ),
                    ),
                  ],

                  if (i.benefits.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Faydalar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 8),
                          for (final b in i.benefits) _Bullet(b),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  if (item.myApplication == null)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _openApplySheet(context, ref, internshipId),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Başvur', style: TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    )
                  else
                    _Card(
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, color: Color(0xFF16A34A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bu staja zaten başvurdun.',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static Future<void> _openApplySheet(BuildContext context, WidgetRef ref, String internshipId) async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) {
        return Padding(
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
              const Text('Motivasyon Mektubu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'Kısaca neden bu staja uygun olduğunu anlat. (En az 100 karakter)',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Örn: Bu staj, ...',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.length < 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('En az 100 karakter yazmalısın.')),
                      );
                      return;
                    }

                    try {
                      await ref.read(internshipDetailProvider(internshipId).notifier).apply(text);
                      if (context.mounted) Navigator.of(context).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Başvurun alındı ✅')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* -------- UI bits -------- */

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
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
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final InternshipApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;

    switch (status) {
      case InternshipApplicationStatus.pending:
        label = 'Beklemede';
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case InternshipApplicationStatus.accepted:
        label = 'Kabul';
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case InternshipApplicationStatus.rejected:
        label = 'Red';
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }
}
