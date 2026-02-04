import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';

class CompanyInternshipApplicationsScreen extends ConsumerStatefulWidget {
  const CompanyInternshipApplicationsScreen({super.key, required this.internshipId});

  final String internshipId;

  @override
  ConsumerState<CompanyInternshipApplicationsScreen> createState() =>
      _CompanyInternshipApplicationsScreenState();
}

class _CompanyInternshipApplicationsScreenState
    extends ConsumerState<CompanyInternshipApplicationsScreen> {
  bool _loading = true;
  String _search = '';
  String _filter = 'all';
  String _internshipTitle = '';
  List<CompanyApplication> _apps = const [];
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (companyId == null || companyId.isEmpty) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(companyRepositoryProvider);
      final internship = await repo.getInternshipById(
        internshipId: widget.internshipId,
        companyId: companyId,
      );
      final list = await repo.listInternshipApplications(internshipId: widget.internshipId);
      if (!mounted) return;
      setState(() {
        _internshipTitle = (internship?['title'] ?? '').toString();
        _apps = list;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(CompanyApplication app, String status) async {
    final repo = ref.read(companyRepositoryProvider);
    await repo.updateInternshipApplicationStatus(applicationId: app.id, status: status);
    if (!mounted) return;
    setState(() {
      _apps = [
        for (final a in _apps)
          if (a.id == app.id) a.copyWith(status: status) else a,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authAsync = ref.watch(authViewStateProvider);
    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    if (auth == null || !auth.isAuthenticated || auth.userType != UserType.company) {
      return Center(child: Text(l10n.t(AppText.companyApplicationsLoginRequired)));
    }

    final filtered = _apps.where((a) {
      if (_filter != 'all' && a.status != _filter) return false;
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return (a.profileName ?? '').toLowerCase().contains(q) ||
          (a.profileEmail ?? '').toLowerCase().contains(q) ||
          (a.profileDepartment ?? '').toLowerCase().contains(q);
    }).toList();

    final total = _apps.length;
    final pending = _apps.where((e) => e.status == 'pending').length;
    final accepted = _apps.where((e) => e.status == 'accepted').length;
    final rejected = _apps.where((e) => e.status == 'rejected').length;

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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go(Routes.companyInternships),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _internshipTitle.isEmpty
                              ? l10n.t(AppText.companyInternshipApplicationsTitle)
                              : l10n.companyInternshipApplicationsTitleWithInternship(_internshipTitle),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MiniStat(label: l10n.t(AppText.commonTotal), value: total),
                      _MiniStat(label: l10n.t(AppText.statusPending), value: pending),
                      _MiniStat(label: l10n.t(AppText.statusAccepted), value: accepted),
                      _MiniStat(label: l10n.t(AppText.statusRejected), value: rejected),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FiltersBar(
                    controller: _searchCtrl,
                    filter: _filter,
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
                    const _EmptyState()
                  else
                    Column(
                      children: [
                        for (final app in filtered)
                          _ApplicationCard(
                            app: app,
                            onUpdateStatus: (status) => _updateStatus(app, status),
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

extension on CompanyApplication {
  CompanyApplication copyWith({String? status}) {
    return CompanyApplication(
      id: id,
      type: type,
      status: status ?? this.status,
      appliedAt: appliedAt,
      profileId: profileId,
      profileName: profileName,
      profileEmail: profileEmail,
      profilePhone: profilePhone,
      profileDepartment: profileDepartment,
      profileYear: profileYear,
      title: title,
      department: department,
      location: location,
      coverLetter: coverLetter,
      motivationLetter: motivationLetter,
      cvUrl: cvUrl,
      jobId: jobId,
      internshipId: internshipId,
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
  });

  final TextEditingController controller;
  final String filter;
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.t(AppText.companyApplicationsSearchHint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
          _FilterChip(
            label: l10n.t(AppText.commonAll),
            active: filter == 'all',
            onTap: () => onFilter('all'),
          ),
          _FilterChip(
            label: l10n.t(AppText.statusPending),
            active: filter == 'pending',
            onTap: () => onFilter('pending'),
          ),
          _FilterChip(
            label: l10n.t(AppText.statusAccepted),
            active: filter == 'accepted',
            onTap: () => onFilter('accepted'),
          ),
          _FilterChip(
            label: l10n.t(AppText.statusRejected),
            active: filter == 'rejected',
            onTap: () => onFilter('rejected'),
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
          color: active ? const Color(0xFF6D28D9) : const Color(0xFFF3F4F6),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.app,
    required this.onUpdateStatus,
  });

  final CompanyApplication app;
  final ValueChanged<String> onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateText = MaterialLocalizations.of(context).formatShortDate(app.appliedAt);

    final dept = (app.profileDepartment ?? '').trim();
    final year = app.profileYear;
    final deptYear = dept.isEmpty
        ? (year == null ? '' : l10n.companyApplicationsYearOfStudy(year))
        : (year == null ? dept : '$dept • ${l10n.companyApplicationsYearOfStudy(year)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.profileName ?? l10n.t(AppText.commonUnnamedCandidate),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(status: app.status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _InfoLine(icon: Icons.mail_outline, text: app.profileEmail ?? l10n.t(AppText.commonNotSpecified)),
              if ((app.profilePhone ?? '').isNotEmpty)
                _InfoLine(icon: Icons.phone, text: app.profilePhone!),
              if (deptYear.isNotEmpty) _InfoLine(icon: Icons.school_outlined, text: deptYear),
              _InfoLine(icon: Icons.event, text: dateText),
            ],
          ),
          if ((app.motivationLetter ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableText(
              title: l10n.t(AppText.companyApplicationsMotivationLetterTitle),
              text: app.motivationLetter!,
            ),
          ],
          if ((app.cvUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _openCv(context, app.cvUrl!),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.t(AppText.companyApplicationsOpenCv)),
            ),
          ],
          if (app.status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onUpdateStatus('accepted'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l10n.t(AppText.commonAccept)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onUpdateStatus('rejected'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(l10n.t(AppText.commonReject)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCv(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.companyApplicationsCvInvalid))),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.companyApplicationsCvOpenFailedCopied))),
      );
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
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
        label = l10n.t(AppText.statusPending);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }
}

class _ExpandableText extends StatelessWidget {
  const _ExpandableText({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(text, style: const TextStyle(color: Color(0xFF374151))),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 44, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 10),
          Text(
            l10n.t(AppText.companyApplicationsEmpty),
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
