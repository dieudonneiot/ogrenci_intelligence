import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';

class CompanyInternshipsScreen extends ConsumerStatefulWidget {
  const CompanyInternshipsScreen({super.key});

  @override
  ConsumerState<CompanyInternshipsScreen> createState() =>
      _CompanyInternshipsScreenState();
}

class _CompanyInternshipsScreenState
    extends ConsumerState<CompanyInternshipsScreen> {
  bool _loading = true;
  String _search = '';
  String _filter = 'all';
  List<CompanyInternshipItem> _internships = const [];
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
      final list = await repo.listInternships(companyId: companyId);
      if (!mounted) return;
      setState(() => _internships = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(CompanyInternshipItem item, bool next) async {
    final repo = ref.read(companyRepositoryProvider);
    await repo.setInternshipActive(item.id, next);
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

    final filtered = _internships.where((i) {
      if (_filter == 'active' && !i.isActive) return false;
      if (_filter == 'inactive' && i.isActive) return false;
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return i.title.toLowerCase().contains(q) ||
          (i.department ?? '').toLowerCase().contains(q) ||
          (i.location ?? '').toLowerCase().contains(q);
    }).toList();

    final activeCount = _internships.where((i) => i.isActive).length;
    final inactiveCount = _internships.length - activeCount;
    final totalApps = _internships.fold<int>(
      0,
      (sum, i) => sum + i.applicationsCount,
    );

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
                            Icons.school_outlined,
                            color: Color(0xFF14B8A6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.t(AppText.companyInternshipsTitle),
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
                          onPressed: () =>
                              context.go(Routes.companyInternshipsCreate),
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
                        value: _internships.length,
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
                      onCreate: () =>
                          context.go(Routes.companyInternshipsCreate),
                      hasSearch: _search.trim().isNotEmpty || _filter != 'all',
                    )
                  else
                    Column(
                      children: [
                        for (final item in filtered)
                          _InternshipCard(
                            item: item,
                            onEdit: () => context.go(
                              '${Routes.companyInternships}/${item.id}/edit',
                            ),
                            onApplications: () => context.go(
                              '${Routes.companyInternships}/${item.id}/applications',
                            ),
                            onToggle: (v) => _toggleStatus(item, v),
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
                hintText: l10n.t(AppText.companyInternshipsSearchHint),
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

class _InternshipCard extends StatelessWidget {
  const _InternshipCard({
    required this.item,
    required this.onEdit,
    required this.onApplications,
    required this.onToggle,
  });

  final CompanyInternshipItem item;
  final VoidCallback onEdit;
  final VoidCallback onApplications;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deadlineText = item.deadline == null
        ? l10n.t(AppText.commonNotSpecified)
        : MaterialLocalizations.of(context).formatShortDate(item.deadline!);

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
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Switch(
                value: item.isActive,
                onChanged: onToggle,
                activeThumbColor: const Color(0xFF14B8A6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${item.department ?? '—'} • ${item.location ?? '—'}',
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
                    '${l10n.t(AppText.commonApplications)}: ${item.applicationsCount}',
              ),
              _InfoChip(
                icon: Icons.check_circle_outline,
                text:
                    '${l10n.t(AppText.statusAccepted)}: ${item.acceptedCount}',
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
          const Icon(Icons.school_outlined, size: 44, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 10),
          Text(
            hasSearch
                ? l10n.t(AppText.noResults)
                : l10n.t(AppText.companyInternshipsEmptyNoListings),
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
