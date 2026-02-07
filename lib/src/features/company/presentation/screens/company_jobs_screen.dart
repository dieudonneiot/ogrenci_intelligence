import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';

class CompanyJobsScreen extends ConsumerStatefulWidget {
  const CompanyJobsScreen({super.key});

  @override
  ConsumerState<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends ConsumerState<CompanyJobsScreen> {
  bool _loading = true;
  String _search = '';
  String _filter = 'all';
  List<CompanyJobItem> _jobs = const [];
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (companyId == null || companyId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(companyRepositoryProvider);
      final list = await repo.listJobs(companyId: companyId);
      if (!mounted) return;
      setState(() => _jobs = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(CompanyJobItem job, bool next) async {
    final repo = ref.read(companyRepositoryProvider);
    await repo.setJobActive(job.id, next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authAsync = ref.watch(authViewStateProvider);
    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.userType != UserType.company) {
      return Center(child: Text(l10n.t(AppText.companyPanelLoginRequired)));
    }

    final filtered = _jobs.where((j) {
      if (_filter == 'active' && !j.isActive) return false;
      if (_filter == 'inactive' && j.isActive) return false;
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return j.title.toLowerCase().contains(q) ||
          (j.department ?? '').toLowerCase().contains(q) ||
          (j.location ?? '').toLowerCase().contains(q);
    }).toList();

    final activeCount = _jobs.where((j) => j.isActive).length;
    final inactiveCount = _jobs.length - activeCount;
    final totalApps = _jobs.fold<int>(0, (sum, j) => sum + j.applicationsCount);

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final isNarrow = c.maxWidth < 520;
                      final titleRow = Row(
                        children: [
                          const Icon(
                            Icons.work_outline,
                            color: Color(0xFF14B8A6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.t(AppText.companyJobsTitle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      );

                      final action = SizedBox(
                        width: isNarrow ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go(Routes.companyJobsCreate),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.t(AppText.newListing)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                          ),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            const SizedBox(height: 10),
                            action,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: titleRow),
                          const SizedBox(width: 12),
                          action,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MiniStat(
                        label: l10n.t(AppText.commonTotal),
                        value: _jobs.length,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.commonActive),
                        value: activeCount,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.commonInactive),
                        value: inactiveCount,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.commonApplications),
                        value: totalApps,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FiltersBar(
                    search: _search,
                    filter: _filter,
                    controller: _searchCtrl,
                    onSearch: (v) => setState(() => _search = v),
                    onFilter: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (filtered.isEmpty)
                    _EmptyState(
                      onCreate: () => context.go(Routes.companyJobsCreate),
                      hasSearch: _search.trim().isNotEmpty || _filter != 'all',
                    )
                  else
                    Column(
                      children: [
                        for (final job in filtered)
                          _JobCard(
                            job: job,
                            onEdit: () => context.go(
                              '${Routes.companyJobs}/${job.id}/edit',
                            ),
                            onApplications: () => context.go(
                              '${Routes.companyJobs}/${job.id}/applications',
                            ),
                            onToggle: (v) => _toggleStatus(job, v),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.search,
    required this.filter,
    required this.controller,
    required this.onSearch,
    required this.onFilter,
  });

  final String search;
  final String filter;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.t(AppText.companyJobsSearchHint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: onSearch,
              controller: controller,
            ),
          ),
          _FilterChip(
            label: l10n.t(AppText.commonAll),
            active: filter == 'all',
            onTap: () => onFilter('all'),
          ),
          _FilterChip(
            label: l10n.t(AppText.commonActive),
            active: filter == 'active',
            onTap: () => onFilter('active'),
          ),
          _FilterChip(
            label: l10n.t(AppText.commonInactive),
            active: filter == 'inactive',
            onTap: () => onFilter('inactive'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF14B8A6) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF374151),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onEdit,
    required this.onApplications,
    required this.onToggle,
  });

  final CompanyJobItem job;
  final VoidCallback onEdit;
  final VoidCallback onApplications;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deadlineText = job.deadline == null
        ? l10n.t(AppText.commonNotSpecified)
        : MaterialLocalizations.of(context).formatShortDate(job.deadline!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Switch(
                value: job.isActive,
                onChanged: onToggle,
                activeThumbColor: const Color(0xFF14B8A6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${job.department ?? '—'} • ${job.location ?? '—'}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _InfoChip(
                icon: Icons.people_outline,
                text:
                    '${l10n.t(AppText.commonApplications)}: ${job.applicationsCount}',
              ),
              _InfoChip(
                icon: Icons.check_circle_outline,
                text: '${l10n.t(AppText.statusAccepted)}: ${job.acceptedCount}',
              ),
              _InfoChip(
                icon: Icons.visibility_outlined,
                text: '${l10n.t(AppText.commonViews)}: ${job.viewsCount}',
              ),
              _InfoChip(
                icon: Icons.event_outlined,
                text: '${l10n.t(AppText.deadline)}: $deadlineText',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onApplications,
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.t(AppText.commonApplications)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.t(AppText.commonEdit)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, required this.hasSearch});

  final VoidCallback onCreate;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.work_outline, size: 44, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 10),
          Text(
            hasSearch
                ? l10n.t(AppText.noResults)
                : l10n.t(AppText.companyJobsEmptyNoListings),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          if (!hasSearch)
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.t(AppText.newListing)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
              ),
            ),
        ],
      ),
    );
  }
}
