import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';

class CompanyDashboardScreen extends ConsumerStatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  ConsumerState<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends ConsumerState<CompanyDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic>? _company;
  CompanyStats _stats = CompanyStats.empty();
  CompanyReportSummary _report = CompanyReportSummary.empty();

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
      final company = await repo.getCompanyById(companyId);
      final stats = await repo.fetchStats(companyId: companyId);
      final report = await repo.fetchReportSummary(
        companyId: companyId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      if (!mounted) return;
      setState(() {
        _company = company;
        _stats = stats;
        _report = report;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
    final user = auth?.user;
    if (auth == null || !auth.isAuthenticated || auth.userType != UserType.company) {
      return const _GuestView();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final companyName = (_company?['name'] ?? '').toString().trim();
    final approvalStatus = (_company?['approval_status'] ?? '').toString();
    final isBanned = _company?['banned_at'] != null;

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
                  _Header(
                    companyName: companyName.isEmpty ? l10n.t(AppText.companyPanel) : companyName,
                    userLabel: user?.email ?? l10n.t(AppText.user),
                  ),
                  const SizedBox(height: 16),
                  if (approvalStatus.isNotEmpty || isBanned)
                    _StatusBanner(
                      status: approvalStatus,
                      isBanned: isBanned,
                      reason: (_company?['rejection_reason'] ?? '').toString(),
                    ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (_, c) {
                      final crossAxis = c.maxWidth >= 980
                          ? 4
                          : c.maxWidth >= 720
                              ? 2
                              : 1;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxis,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          _StatCard(
                            title: l10n.t(AppText.companyDashboardActiveJobs),
                            value: _stats.activeJobs.toString(),
                            color: const Color(0xFF7C3AED),
                            icon: Icons.work_outline,
                          ),
                          _StatCard(
                            title: l10n.t(AppText.companyDashboardActiveInternships),
                            value: _stats.activeInternships.toString(),
                            color: const Color(0xFF2563EB),
                            icon: Icons.school_outlined,
                          ),
                          _StatCard(
                            title: l10n.t(AppText.companyDashboardPendingApplications),
                            value: _stats.pendingApplications.toString(),
                            color: const Color(0xFFF59E0B),
                            icon: Icons.pending_actions,
                          ),
                          _StatCard(
                            title: l10n.t(AppText.companyDashboardTotalApplications),
                            value: _stats.totalApplications.toString(),
                            color: const Color(0xFF16A34A),
                            icon: Icons.people_outline,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _QuickActions(),
                  const SizedBox(height: 20),
                  _PerformanceSummary(report: _report),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.companyName,
    required this.userLabel,
  });

  final String companyName;
  final String userLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.companyDashboardWelcome(userLabel),
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.isBanned,
    required this.reason,
  });

  final String status;
  final bool isBanned;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isBanned) {
      return _banner(
        icon: Icons.block,
        color: const Color(0xFFB91C1C),
        bg: const Color(0xFFFFF1F2),
        text: l10n.t(AppText.companyDashboardStatusBanned),
      );
    }

    if (status == 'pending') {
      return _banner(
        icon: Icons.hourglass_bottom,
        color: const Color(0xFFB45309),
        bg: const Color(0xFFFFFBEB),
        text: l10n.t(AppText.companyDashboardStatusPending),
      );
    }

    if (status == 'rejected') {
      final msg = reason.isEmpty
          ? l10n.t(AppText.companyDashboardStatusRejected)
          : l10n.companyDashboardStatusRejectedWithReason(reason);
      return _banner(
        icon: Icons.error_outline,
        color: const Color(0xFFB91C1C),
        bg: const Color(0xFFFFF1F2),
        text: msg,
      );
    }

    if (status.isNotEmpty && status != 'approved') {
      return _banner(
        icon: Icons.info_outline,
        color: const Color(0xFF2563EB),
        bg: const Color(0xFFEFF6FF),
        text: l10n.companyDashboardStatusOther(status),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _banner({required IconData icon, required Color color, required Color bg, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t(AppText.companyDashboardQuickActionsTitle),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionCard(
              icon: Icons.add_circle_outline,
              label: l10n.t(AppText.companyDashboardQuickActionNewJob),
              onTap: () => context.go(Routes.companyJobsCreate),
            ),
            _ActionCard(
              icon: Icons.work_outline,
              label: l10n.t(AppText.companyJobsTitle),
              onTap: () => context.go(Routes.companyJobs),
            ),
            _ActionCard(
              icon: Icons.people_outline,
              label: l10n.t(AppText.companyApplicationsTitle),
              onTap: () => context.go(Routes.companyApplications),
            ),
            _ActionCard(
              icon: Icons.bar_chart_outlined,
              label: l10n.t(AppText.companyReportsTitle),
              onTap: () => context.go(Routes.companyReports),
            ),
          ],
        ),
      ],
    );
  }
}

class _PerformanceSummary extends StatelessWidget {
  const _PerformanceSummary({required this.report});

  final CompanyReportSummary report;

  double _cap(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewRatio = _cap(report.totalViews / 500.0);
    final conversionRatio = _cap(report.conversionRate / 100);
    final responseRatio = _cap(1 - (report.avgResponseTimeHours / 72));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t(AppText.companyDashboardPerformanceSummaryTitle),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: l10n.t(AppText.companyReportsMetricTotalViews),
            value: report.totalViews.toString(),
            ratio: viewRatio,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            label: l10n.t(AppText.companyReportsMetricConversionRate),
            value: '%${report.conversionRate.toStringAsFixed(1)}',
            ratio: conversionRatio,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            label: l10n.t(AppText.companyReportsMetricAvgResponseTime),
            value: '${report.avgResponseTimeHours.toStringAsFixed(1)} ${l10n.t(AppText.companyReportsHoursUnit)}',
            ratio: responseRatio,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(value, style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF6D28D9)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(child: Text(l10n.t(AppText.companyPanelLoginRequired)));
  }
}

