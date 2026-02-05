import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/utils/csv_export.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';

String _formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class CompanyApplicationsScreen extends ConsumerStatefulWidget {
  const CompanyApplicationsScreen({super.key});

  @override
  ConsumerState<CompanyApplicationsScreen> createState() =>
      _CompanyApplicationsScreenState();
}

class _CompanyApplicationsScreenState
    extends ConsumerState<CompanyApplicationsScreen> {
  bool _loading = true;
  List<CompanyApplication> _apps = const [];
  String _search = '';
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  final Set<String> _sendingFocus = <String>{};
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
      final list = await repo.listCompanyApplications(companyId: companyId);
      if (!mounted) return;
      setState(() => _apps = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(CompanyApplication app, String status) async {
    final repo = ref.read(companyRepositoryProvider);
    if (app.type == 'job') {
      await repo.updateJobApplicationStatus(
        applicationId: app.id,
        status: status,
      );
    } else {
      await repo.updateInternshipApplicationStatus(
        applicationId: app.id,
        status: status,
      );
    }
    if (!mounted) return;
    setState(() {
      _apps = [
        for (final a in _apps)
          if (a.id == app.id) a.copyWith(status: status) else a,
      ];
    });
  }

  Future<void> _exportCsv(List<CompanyApplication> list) async {
    final l10n = AppLocalizations.of(context);
    final buffer = StringBuffer();
    buffer.writeln(l10n.t(AppText.companyApplicationsCsvHeader));
    for (final app in list) {
      buffer.writeln(
        [
          _escape(app.profileName ?? ''),
          _escape(app.profileEmail ?? ''),
          _escape(app.profilePhone ?? ''),
          _escape(
            app.type == 'job'
                ? l10n.t(AppText.companyApplicationsCsvTypeJob)
                : l10n.t(AppText.companyApplicationsCsvTypeInternship),
          ),
          _escape(app.title ?? ''),
          _escape(app.department ?? ''),
          _escape(_statusText(l10n, app.status)),
          _escape(_formatDate(app.appliedAt)),
        ].join(','),
      );
    }

    final now = DateTime.now();
    final fileName =
        'applications-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
    await downloadCsv(buffer.toString(), fileName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t(AppText.companyApplicationsCsvDownloaded))),
    );
  }

  Future<void> _sendFocusCheck(CompanyApplication app) async {
    if (app.type != 'internship') return;
    if (app.status != 'accepted') return;
    if (app.profileId == null || app.profileId!.isEmpty) return;

    setState(() => _sendingFocus.add(app.id));
    try {
      final focusId = await SupabaseService.client.rpc(
        'company_create_focus_check',
        params: {
          'p_user_id': app.profileId,
          'p_internship_application_id': app.id,
          'p_question': null,
          'p_expires_in_seconds': 30,
        },
      );

      final id = (focusId ?? '').toString();
      if (id.isEmpty) throw Exception('Failed to create focus check');

      await SupabaseService.client.functions.invoke(
        'push',
        body: {'focus_check_id': id},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Focus check sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _sendingFocus.remove(app.id));
    }
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
      return Center(
        child: Text(l10n.t(AppText.companyApplicationsLoginRequired)),
      );
    }

    final filtered = _apps.where((a) {
      if (_statusFilter != 'all' && a.status != _statusFilter) return false;
      if (_typeFilter != 'all' && a.type != _typeFilter) return false;
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return (a.profileName ?? '').toLowerCase().contains(q) ||
          (a.profileEmail ?? '').toLowerCase().contains(q) ||
          (a.title ?? '').toLowerCase().contains(q);
    }).toList();

    final total = _apps.length;
    final pending = _apps.where((e) => e.status == 'pending').length;
    final accepted = _apps.where((e) => e.status == 'accepted').length;
    final rejected = _apps.where((e) => e.status == 'rejected').length;
    final jobCount = _apps.where((e) => e.type == 'job').length;
    final internshipCount = _apps.where((e) => e.type == 'internship').length;

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (_, c) {
                      final isNarrow = c.maxWidth < 640;
                      final titleRow = Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            color: Color(0xFF6D28D9),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.t(AppText.companyApplicationsTitle),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _exportCsv(filtered),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(
                              l10n.t(AppText.companyReportsExportCsv),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            const SizedBox(height: 8),
                            actions,
                          ],
                        );
                      }

                      return Row(children: [titleRow, const Spacer(), actions]);
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MiniStat(
                        label: l10n.t(AppText.commonTotal),
                        value: total,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.statusPending),
                        value: pending,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.statusAccepted),
                        value: accepted,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.statusRejected),
                        value: rejected,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.jobsTitle),
                        value: jobCount,
                      ),
                      _MiniStat(
                        label: l10n.t(AppText.internshipsTitle),
                        value: internshipCount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FiltersBar(
                    controller: _searchCtrl,
                    statusFilter: _statusFilter,
                    typeFilter: _typeFilter,
                    onSearch: (v) => setState(() => _search = v),
                    onStatus: (v) => setState(() => _statusFilter = v),
                    onType: (v) => setState(() => _typeFilter = v),
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
                            onUpdateStatus: (status) =>
                                _updateStatus(app, status),
                            onSendFocusCheck: _sendingFocus.contains(app.id)
                                ? null
                                : () => _sendFocusCheck(app),
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

  String _statusText(AppLocalizations l10n, String status) {
    switch (status) {
      case 'accepted':
        return l10n.t(AppText.statusAccepted);
      case 'rejected':
        return l10n.t(AppText.statusRejected);
      default:
        return l10n.t(AppText.statusPending);
    }
  }

  String _escape(String input) {
    final escaped = input.replaceAll('"', '""');
    return '"$escaped"';
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
    required this.statusFilter,
    required this.typeFilter,
    required this.onSearch,
    required this.onStatus,
    required this.onType,
  });

  final TextEditingController controller;
  final String statusFilter;
  final String typeFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onType;

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
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.t(AppText.companyApplicationsSearchHint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          _FilterChip(
            label: l10n.t(AppText.companyApplicationsFilterAllStatuses),
            active: statusFilter == 'all',
            onTap: () => onStatus('all'),
          ),
          _FilterChip(
            label: l10n.t(AppText.statusPending),
            active: statusFilter == 'pending',
            onTap: () => onStatus('pending'),
          ),
          _FilterChip(
            label: l10n.t(AppText.statusAccepted),
            active: statusFilter == 'accepted',
            onTap: () => onStatus('accepted'),
          ),
          _FilterChip(
            label: l10n.t(AppText.statusRejected),
            active: statusFilter == 'rejected',
            onTap: () => onStatus('rejected'),
          ),
          _FilterChip(
            label: l10n.t(AppText.companyApplicationsFilterAllTypes),
            active: typeFilter == 'all',
            onTap: () => onType('all'),
          ),
          _FilterChip(
            label: l10n.t(AppText.jobsTitle),
            active: typeFilter == 'job',
            onTap: () => onType('job'),
          ),
          _FilterChip(
            label: l10n.t(AppText.internshipsTitle),
            active: typeFilter == 'internship',
            onTap: () => onType('internship'),
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
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.app,
    required this.onUpdateStatus,
    required this.onSendFocusCheck,
  });

  final CompanyApplication app;
  final ValueChanged<String> onUpdateStatus;
  final VoidCallback? onSendFocusCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isJob = app.type == 'job';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  app.profileName ?? l10n.t(AppText.commonNotSpecified),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _TypePill(type: app.type),
              const SizedBox(width: 8),
              _StatusPill(status: app.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${app.title ?? '-'} • ${app.department ?? '-'}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _InfoLine(
                icon: Icons.mail_outline,
                text: app.profileEmail ?? l10n.t(AppText.commonNotSpecified),
              ),
              if ((app.profilePhone ?? '').isNotEmpty)
                _InfoLine(icon: Icons.phone, text: app.profilePhone!),
              if ((app.profileDepartment ?? '').isNotEmpty)
                _InfoLine(
                  icon: Icons.school_outlined,
                  text:
                      '${app.profileDepartment}${app.profileYear != null ? ' • ${l10n.companyApplicationsYearOfStudy(app.profileYear!)}' : ''}',
                ),
              _InfoLine(icon: Icons.event, text: _formatDate(app.appliedAt)),
            ],
          ),
          if ((app.coverLetter ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableText(
              title: l10n.t(AppText.companyApplicationsCoverLetterTitle),
              text: app.coverLetter!,
            ),
          ],
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
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  if (isJob && app.jobId != null) {
                    context.go(
                      '${Routes.companyJobs}/${app.jobId}/applications',
                    );
                  } else if (!isJob && app.internshipId != null) {
                    context.go(
                      '${Routes.companyInternships}/${app.internshipId}/applications',
                    );
                  }
                },
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l10n.t(AppText.commonViewDetails)),
              ),
              if (!isJob &&
                  app.status == 'accepted' &&
                  app.profileId != null &&
                  app.profileId!.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSendFocusCheck,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text(
                    'Send Focus Check',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
              const Spacer(),
              if (app.status == 'pending') ...[
                ElevatedButton.icon(
                  onPressed: () => onUpdateStatus('accepted'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.t(AppText.commonAccept)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => onUpdateStatus('rejected'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(l10n.t(AppText.commonReject)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
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
        SnackBar(
          content: Text(l10n.t(AppText.companyApplicationsCvOpenFailedCopied)),
        ),
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
        Text(
          text,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isJob = type == 'job';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isJob ? const Color(0xFFE0F2FE) : const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isJob ? l10n.t(AppText.jobsTitle) : l10n.t(AppText.internshipsTitle),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: isJob ? const Color(0xFF0369A1) : const Color(0xFF6D28D9),
        ),
      ),
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
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
