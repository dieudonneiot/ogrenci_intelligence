import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../application/jobs_providers.dart';
import '../../domain/job_models.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applySearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final f = ref.read(jobsFiltersProvider);
      ref.read(jobsFiltersProvider.notifier).state = f.copyWith(query: v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = ref.watch(jobsFiltersProvider);
    final asyncVm = ref.watch(jobsProvider);

    if (_searchCtrl.text != filters.query) {
      // keep UI synced (without infinite loops)
      _searchCtrl.text = filters.query;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchCtrl.text.length),
      );
    }

    return asyncVm.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                l10n.t(AppText.jobsLoadFailed),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => ref.read(jobsProvider.notifier).refresh(),
                  child: Text(l10n.t(AppText.retry)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (vm) {
        return Container(
          color: const Color(0xFFF9FAFB),
          child: RefreshIndicator(
            onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
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
                          l10n.t(AppText.jobsTitle),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.t(AppText.jobsSubtitle),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Search
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: _applySearch,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: l10n.t(AppText.jobsSearchHint),
                                  ),
                                ),
                              ),
                              if (filters.query.isNotEmpty)
                                IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _applySearch('');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Filters
                        _FiltersRow(
                          vm: vm,
                          filters: filters,
                          onChange: (next) => ref.read(jobsFiltersProvider.notifier).state = next,
                        ),

                        const SizedBox(height: 14),

                        if (vm.items.isEmpty)
                          _Empty(text: l10n.t(AppText.noResults))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: vm.items.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _JobCard(item: vm.items[i]),
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

/* ---------------- UI ---------------- */

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.vm,
    required this.filters,
    required this.onChange,
  });

  final JobsViewModel vm;
  final JobsFilters filters;
  final ValueChanged<JobsFilters> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          selected: filters.remoteOnly,
          onSelected: (v) => onChange(filters.copyWith(remoteOnly: v)),
          label: Text(AppLocalizations.of(context).t(AppText.remote)),
          selectedColor: const Color(0xFFEDE9FE),
          checkmarkColor: const Color(0xFF6D28D9),
        ),
        _DropdownFilter(
          label: AppLocalizations.of(context).t(AppText.filterDepartment),
          value: filters.department,
          items: vm.availableDepartments,
          onChanged: (v) => onChange(filters.copyWith(department: v)),
          onClear: () => onChange(filters.copyWith(clearDepartment: true)),
        ),
        _DropdownFilter(
          label: AppLocalizations.of(context).t(AppText.filterWorkType),
          value: filters.workType,
          items: vm.availableWorkTypes,
          onChanged: (v) => onChange(filters.copyWith(workType: v)),
          onClear: () => onChange(filters.copyWith(clearWorkType: true)),
        ),
      ],
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.onClear,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: (value != null && value!.isNotEmpty && items.contains(value)) ? value : null,
            hint: Text(AppLocalizations.of(context).t(AppText.select)),
            underline: const SizedBox.shrink(),
            items: items
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(growable: false),
            onChanged: onChanged,
          ),
          if (value != null && value!.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.item});
  final JobCardVM item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final j = item.job;
    final applied = item.applicationStatus != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('${Routes.jobs}/${j.id}'),
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
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(14),
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
                        child: Text(
                          j.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (applied) _StatusPill(status: item.applicationStatus!),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${j.companyName} • ${j.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(text: j.department, bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9)),
                      _Chip(text: j.workType, bg: const Color(0xFFF3F4F6), fg: const Color(0xFF374151)),
                      if (j.isRemote)
                        _Chip(text: l10n.t(AppText.remote), bg: const Color(0xFFDCFCE7), fg: const Color(0xFF16A34A)),
                      if (j.deadline != null)
                        _Chip(
                          text: l10n.deadlineLabel(_fmtDate(j.deadline!)),
                          bg: const Color(0xFFFFF7ED),
                          fg: const Color(0xFFB45309),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: item.isFavorite
                  ? l10n.t(AppText.favoriteRemove)
                  : l10n.t(AppText.favoriteAdd),
              onPressed: () async {
                try {
                  await ref.read(jobsProvider.notifier).toggleFavorite(j.id);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.favoriteUpdateFailed('$e'))),
                  );
                }
              },
              icon: Icon(item.isFavorite ? Icons.favorite : Icons.favorite_border, color: const Color(0xFFEF4444)),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
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
    final l10n = AppLocalizations.of(context);
    final s = status.toLowerCase().trim();
    Color bg;
    Color fg;
    String label;

    switch (s) {
      case 'accepted':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = l10n.t(AppText.statusAccepted);
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = l10n.t(AppText.statusRejected);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = l10n.t(AppText.statusApplied);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
      ),
    );
  }
}
