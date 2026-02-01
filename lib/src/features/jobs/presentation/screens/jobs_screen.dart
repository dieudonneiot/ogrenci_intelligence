import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../application/jobs_providers.dart';
import '../../domain/job_models.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      final cur = ref.read(jobFiltersProvider);
      ref.read(jobFiltersProvider.notifier).state = cur.copyWith(query: v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncVm = ref.watch(jobsListProvider);
    final filters = ref.watch(jobFiltersProvider);

    return Container(
      color: const Color(0xFFF9FAFB),
      child: RefreshIndicator(
        onRefresh: () => ref.read(jobsListProvider.notifier).refresh(),
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
                      children: const [
                        Icon(Icons.work_outline, color: Color(0xFF2563EB), size: 28),
                        SizedBox(width: 10),
                        Text('İş İlanları', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sana uygun işleri bul, kaydet ve hızlıca başvur.',
                      style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),

                    // Search + Filters
                    _Card(
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Ara: title, şirket, bölüm, lokasyon...',
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (filters.remoteOnly)
                                      _Chip(label: 'Remote', icon: Icons.wifi_tethering, onClear: () {
                                        ref.read(jobFiltersProvider.notifier).state =
                                            filters.copyWith(remoteOnly: false);
                                      }),
                                    if ((filters.department ?? '').isNotEmpty)
                                      _Chip(label: filters.department!, icon: Icons.school, onClear: () {
                                        ref.read(jobFiltersProvider.notifier).state =
                                            filters.copyWith(department: null);
                                      }),
                                    if ((filters.workType ?? '').isNotEmpty)
                                      _Chip(label: filters.workType!, icon: Icons.schedule, onClear: () {
                                        ref.read(jobFiltersProvider.notifier).state =
                                            filters.copyWith(workType: null);
                                      }),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openFilters(context, filters),
                                  icon: const Icon(Icons.tune),
                                  label: const Text('Filtrele'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    asyncVm.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      ),
                      error: (e, _) => _ErrorBlock(
                        title: 'İş ilanları yüklenemedi',
                        message: e.toString(),
                        onRetry: () => ref.read(jobsListProvider.notifier).refresh(),
                      ),
                      data: (vm) {
                        if (vm.items.isEmpty) {
                          return const _EmptyBlock(
                            icon: Icons.search_off,
                            title: 'Sonuç yok',
                            message: 'Filtreleri değiştirip tekrar deneyebilirsin.',
                          );
                        }

                        return ListView.separated(
                          itemCount: vm.items.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final j = vm.items[i];
                            final isFav = vm.favoriteJobIds.contains(j.id);
                            return _JobCard(
                              job: j,
                              isFavorited: isFav,
                              onOpen: () => context.go('${Routes.jobs}/${j.id}'),
                              onToggleFav: () async {
                                try {
                                  await ref.read(jobsListProvider.notifier).toggleFavorite(j.id);
                                } catch (_) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Favori güncellenemedi')),
                                  );
                                }
                              },
                            );
                          },
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
  }

  Future<void> _openFilters(BuildContext context, JobFilters filters) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(filters: filters),
    );
  }
}

/* ---------------- UI ---------------- */

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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.onClear});
  final String label;
  final IconData icon;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF374151)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.isFavorited,
    required this.onOpen,
    required this.onToggleFav,
  });

  final JobSummary job;
  final bool isFavorited;
  final VoidCallback onOpen;
  final VoidCallback onToggleFav;

  @override
  Widget build(BuildContext context) {
    final remote = job.isRemote ? 'Remote' : 'On-site';
    final wt = (job.workType ?? '').trim();
    final loc = (job.location ?? '').trim();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.work_outline, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        onPressed: onToggleFav,
                        icon: Icon(
                          isFavorited ? Icons.bookmark : Icons.bookmark_border,
                          color: isFavorited ? const Color(0xFF6D28D9) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.company,
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(remote, job.isRemote ? const Color(0xFF16A34A) : const Color(0xFF374151)),
                      if (wt.isNotEmpty) _pill(wt, const Color(0xFF2563EB)),
                      if (loc.isNotEmpty) _pill(loc, const Color(0xFF6B7280)),
                      if ((job.salary ?? '').trim().isNotEmpty) _pill(job.salary!.trim(), const Color(0xFF92400E)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: color)),
    );
  }
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet({required this.filters});
  final JobFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptCtrl = TextEditingController(text: filters.department ?? '');
    final wtCtrl = TextEditingController(text: filters.workType ?? '');

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
                child: Text('Filtreler', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: filters.remoteOnly,
            onChanged: (v) => ref.read(jobFiltersProvider.notifier).state = filters.copyWith(remoteOnly: v),
            title: const Text('Sadece Remote'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: deptCtrl,
            decoration: const InputDecoration(
              labelText: 'Bölüm (department)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(jobFiltersProvider.notifier).state =
                filters.copyWith(department: v.trim().isEmpty ? null : v.trim()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: wtCtrl,
            decoration: const InputDecoration(
              labelText: 'Çalışma tipi (work_type)',
              hintText: 'full-time, part-time, ...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(jobFiltersProvider.notifier).state =
                filters.copyWith(workType: v.trim().isEmpty ? null : v.trim()),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(jobFiltersProvider.notifier).state = const JobFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Sıfırla'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

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
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.title, required this.message, required this.onRetry});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      ),
    );
  }
}
