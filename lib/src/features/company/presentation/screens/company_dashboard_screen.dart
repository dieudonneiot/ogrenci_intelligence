import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';
import '../../../evidence/data/evidence_repository.dart';
import '../../../evidence/domain/evidence_models.dart';
import '../../../excuse/data/excuse_repository.dart';
import '../../../excuse/domain/excuse_models.dart';
import '../../data/talent_mining_repository.dart';
import '../../domain/talent_models.dart';

class CompanyDashboardScreen extends ConsumerStatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  ConsumerState<CompanyDashboardScreen> createState() =>
      _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState
    extends ConsumerState<CompanyDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic>? _company;
  CompanyStats _stats = CompanyStats.empty();
  CompanyReportSummary _report = CompanyReportSummary.empty();
  int _activeInterns = 0;
  int _pendingEvidence = 0;
  int _pendingExcuses = 0;
  int _avgOiScore = 0;
  Map<String, int> _departmentDistribution = const {};
  List<_CompanyFeedItem> _feed = const [];
  List<TalentCandidate> _talentPool = const [];
  String? _talentError;
  String? _talentDepartment;
  bool _matchSector = true;

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
      final evidenceRepo = const EvidenceRepository();
      final excuseRepo = const ExcuseRepository();
      final talentRepo = const TalentMiningRepository();

      final results = await Future.wait([
        repo.getCompanyById(companyId),
        repo.fetchStats(companyId: companyId),
        repo.fetchReportSummary(
          companyId: companyId,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        evidenceRepo.listCompanyPendingEvidence(companyId: companyId, limit: 6),
        excuseRepo.listCompanyRequests(
          companyId: companyId,
          status: 'pending',
          limit: 6,
        ),
        _loadActiveInterns(companyId),
        _loadTalentPool(talentRepo, companyId),
      ]);

      final company = results[0] as Map<String, dynamic>?;
      final stats = results[1] as CompanyStats;
      final report = results[2] as CompanyReportSummary;
      final pendingEvidenceItems = results[3] as List<EvidenceItem>;
      final pendingExcuses = results[4] as List<CompanyExcuseRequest>;
      final internBundle = results[5] as _InternBundle;
      final talentBundle = results[6] as _TalentBundle;

      final evidenceUserIds = pendingEvidenceItems
          .map((e) => e.userId)
          .where((e) => e.isNotEmpty)
          .toSet();
      Map<String, String> nameByUserId = {};
      if (evidenceUserIds.isNotEmpty) {
        final rows = await SupabaseService.client
            .from('profiles')
            .select('id, full_name, email')
            .inFilter('id', evidenceUserIds.toList(growable: false));
        nameByUserId = {
          for (final r in (rows as List))
            (r as Map<String, dynamic>)['id']?.toString() ?? '':
                ((r['full_name'] ?? r['email'] ?? '').toString()),
        }..removeWhere((k, v) => k.isEmpty);
      }

      final feed = <_CompanyFeedItem>[
        for (final e in pendingEvidenceItems.take(4))
          _CompanyFeedItem(
            kind: _FeedKind.evidence,
            message: '${nameByUserId[e.userId] ?? 'A student'} uploaded proof.',
            createdAt: e.createdAt,
          ),
        for (final r in pendingExcuses.take(4))
          _CompanyFeedItem(
            kind: _FeedKind.excuse,
            message:
                '${r.studentName.isEmpty ? 'A student' : r.studentName} reported an excuse.',
            createdAt: r.createdAt,
          ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _company = company;
        _stats = stats;
        _report = report;
        _pendingEvidence = pendingEvidenceItems.length;
        _pendingExcuses = pendingExcuses.length;
        _activeInterns = internBundle.activeInterns;
        _avgOiScore = internBundle.avgOiScore;
        _departmentDistribution = internBundle.departmentDistribution;
        _feed = feed.take(6).toList(growable: false);
        _talentPool = talentBundle.items;
        _talentError = talentBundle.error;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_TalentBundle> _loadTalentPool(
    TalentMiningRepository repo,
    String companyId,
  ) async {
    try {
      final items = await repo.listTalentPool(
        companyId: companyId,
        department: null,
        minScore: 0,
        maxScore: 100,
        limit: 80,
        offset: 0,
      );
      return _TalentBundle(items: items, error: null);
    } catch (e) {
      return _TalentBundle(items: const [], error: e.toString());
    }
  }

  bool _matchesSector(TalentCandidate c, String sector) {
    final s = sector.trim().toLowerCase();
    if (s.isEmpty) return false;
    final d = (c.department ?? '').trim().toLowerCase();
    if (d.isEmpty) return false;
    return d.contains(s) || s.contains(d);
  }

  Future<_InternBundle> _loadActiveInterns(String companyId) async {
    final internshipRows = await SupabaseService.client
        .from('internships')
        .select('id')
        .eq('company_id', companyId);
    final internshipIds = (internshipRows as List)
        .map((e) => (e as Map<String, dynamic>)['id']?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (internshipIds.isEmpty) {
      return const _InternBundle(
        activeInterns: 0,
        avgOiScore: 0,
        departmentDistribution: <String, int>{},
      );
    }

    final appsRows = await SupabaseService.client
        .from('internship_applications')
        .select('user_id')
        .inFilter('internship_id', internshipIds)
        .eq('status', 'accepted');

    final userIds = (appsRows as List)
        .map((e) => (e as Map<String, dynamic>)['user_id']?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (userIds.isEmpty) {
      return const _InternBundle(
        activeInterns: 0,
        avgOiScore: 0,
        departmentDistribution: <String, int>{},
      );
    }

    final profRows = await SupabaseService.client
        .from('profiles')
        .select('department')
        .inFilter('id', userIds);
    final dist = <String, int>{};
    for (final r in (profRows as List)) {
      final dept = ((r as Map<String, dynamic>)['department'] ?? '')
          .toString()
          .trim();
      if (dept.isEmpty) continue;
      dist[dept] = (dist[dept] ?? 0) + 1;
    }

    var avg = 0;
    final oiRows = await SupabaseService.client
        .from('oi_scores')
        .select('oi_score')
        .inFilter('user_id', userIds);
    var sum = 0;
    var count = 0;
    for (final r in (oiRows as List)) {
      final v = (r as Map<String, dynamic>)['oi_score'];
      final s = v is int ? v : int.tryParse(v?.toString() ?? '');
      if (s == null) continue;
      sum += s;
      count++;
    }
    if (count > 0) avg = (sum / count).round();

    return _InternBundle(
      activeInterns: userIds.length,
      avgOiScore: avg,
      departmentDistribution: dist,
    );
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
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.userType != UserType.company) {
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
                    companyName: companyName.isEmpty
                        ? l10n.t(AppText.companyPanel)
                        : companyName,
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
                            title: l10n.t(
                              AppText.companyDashboardActiveInternships,
                            ),
                            value: _stats.activeInternships.toString(),
                            color: const Color(0xFF2563EB),
                            icon: Icons.school_outlined,
                          ),
                          _StatCard(
                            title: l10n.t(
                              AppText.companyDashboardPendingApplications,
                            ),
                            value: _stats.pendingApplications.toString(),
                            color: const Color(0xFFF59E0B),
                            icon: Icons.pending_actions,
                          ),
                          _StatCard(
                            title: l10n.t(
                              AppText.companyDashboardTotalApplications,
                            ),
                            value: _stats.totalApplications.toString(),
                            color: const Color(0xFF16A34A),
                            icon: Icons.people_outline,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (_, c) {
                      final crossAxis = c.maxWidth >= 980
                          ? 3
                          : c.maxWidth >= 720
                          ? 3
                          : 1;
                      final pendingApprovals =
                          _pendingEvidence + _pendingExcuses;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxis,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.55,
                        children: [
                          _StatCard(
                            title: 'Active interns',
                            value: _activeInterns.toString(),
                            color: const Color(0xFF2563EB),
                            icon: Icons.badge_outlined,
                          ),
                          _StatCard(
                            title: 'Pending approvals',
                            value: pendingApprovals.toString(),
                            color: pendingApprovals > 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF6B7280),
                            icon: Icons.notifications_active_outlined,
                          ),
                          _StatCard(
                            title: 'Average OI score',
                            value: _avgOiScore.toString(),
                            color: const Color(0xFF16A34A),
                            icon: Icons.insights_outlined,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _QuickActions(),
                  const SizedBox(height: 14),
                  _TalentSpotlight(
                    sector: (_company?['sector'] ?? '').toString(),
                    candidates: _talentPool,
                    error: _talentError,
                    selectedDepartment: _talentDepartment,
                    matchSector: _matchSector,
                    onChangeFilters: (nextDepartment, matchSector) {
                      setState(() {
                        _talentDepartment = nextDepartment;
                        _matchSector = matchSector;
                      });
                    },
                    onSeeAll: () => context.go(Routes.companyTalent),
                    matchesSector: _matchesSector,
                  ),
                  const SizedBox(height: 14),
                  _NotificationFeed(
                    items: _feed,
                    onOpenEvidence: () => context.go(Routes.companyEvidence),
                    onOpenExcuses: () => context.go(Routes.companyExcuses),
                  ),
                  const SizedBox(height: 14),
                  if (_departmentDistribution.isNotEmpty)
                    _DepartmentChart(distribution: _departmentDistribution),
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
  const _Header({required this.companyName, required this.userLabel});

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
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.companyDashboardWelcome(userLabel),
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
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

  Widget _banner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) {
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
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
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
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            title,
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

enum _FeedKind { evidence, excuse }

@immutable
class _CompanyFeedItem {
  const _CompanyFeedItem({
    required this.kind,
    required this.message,
    required this.createdAt,
  });

  final _FeedKind kind;
  final String message;
  final DateTime createdAt;
}

@immutable
class _InternBundle {
  const _InternBundle({
    required this.activeInterns,
    required this.avgOiScore,
    required this.departmentDistribution,
  });

  final int activeInterns;
  final int avgOiScore;
  final Map<String, int> departmentDistribution;
}

class _NotificationFeed extends StatelessWidget {
  const _NotificationFeed({
    required this.items,
    required this.onOpenEvidence,
    required this.onOpenExcuses,
  });

  final List<_CompanyFeedItem> items;
  final VoidCallback onOpenEvidence;
  final VoidCallback onOpenExcuses;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notification Feed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: onOpenEvidence,
                child: const Text(
                  'Evidence',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onOpenExcuses,
                child: const Text(
                  'Excuses',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = items[i];
              final icon = it.kind == _FeedKind.evidence
                  ? Icons.verified_outlined
                  : Icons.event_busy_outlined;
              final color = it.kind == _FeedKind.evidence
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFFF59E0B);
              final onTap = it.kind == _FeedKind.evidence
                  ? onOpenEvidence
                  : onOpenExcuses;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          it.message,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DepartmentChart extends StatelessWidget {
  const _DepartmentChart({required this.distribution});

  final Map<String, int> distribution;

  @override
  Widget build(BuildContext context) {
    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxV = sorted.isEmpty ? 1 : sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Department distribution',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final e in sorted.take(8)) ...[
            Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: e.value / maxV,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text(
                    e.value.toString(),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
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
            value:
                '${report.avgResponseTimeHours.toStringAsFixed(1)} ${l10n.t(AppText.companyReportsHoursUnit)}',
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
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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

class _TalentBundle {
  const _TalentBundle({required this.items, required this.error});

  final List<TalentCandidate> items;
  final String? error;
}

class _TalentSpotlight extends StatelessWidget {
  const _TalentSpotlight({
    required this.sector,
    required this.candidates,
    required this.error,
    required this.selectedDepartment,
    required this.matchSector,
    required this.onChangeFilters,
    required this.onSeeAll,
    required this.matchesSector,
  });

  final String sector;
  final List<TalentCandidate> candidates;
  final String? error;
  final String? selectedDepartment;
  final bool matchSector;
  final void Function(String? department, bool matchSector) onChangeFilters;
  final VoidCallback onSeeAll;
  final bool Function(TalentCandidate c, String sector) matchesSector;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sectorTrimmed = sector.trim();
    final effectiveMatchSector = matchSector && sectorTrimmed.isNotEmpty;

    final departments = candidates
        .map((e) => (e.department ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    Iterable<TalentCandidate> filtered = candidates;
    final dep = (selectedDepartment ?? '').trim();
    if (dep.isNotEmpty) {
      filtered = filtered.where((c) => (c.department ?? '').trim() == dep);
    }
    if (effectiveMatchSector) {
      filtered = filtered.where((c) => matchesSector(c, sectorTrimmed));
    }

    final list = filtered.toList(growable: false)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    final top = list.take(10).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline, color: Color(0xFF6D28D9)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Top Students',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openFilterSheet(
                  context,
                  departments: departments,
                  sector: sectorTrimmed,
                ),
                icon: const Icon(Icons.filter_list),
                label: const Text('Filter'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (dep.isNotEmpty)
                _Chip(
                  icon: Icons.school_outlined,
                  label: dep,
                  onClear: () => onChangeFilters(null, matchSector),
                ),
              if (effectiveMatchSector)
                _Chip(
                  icon: Icons.business_outlined,
                  label: 'Match sector: $sectorTrimmed',
                  onClear: () => onChangeFilters(selectedDepartment, false),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if ((error ?? '').trim().isNotEmpty && candidates.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Talent pool is not available yet for this project. Apply `docs/sql/24_talent_mining.sql` in Supabase and try again.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else if (top.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                effectiveMatchSector
                    ? 'No students match your company sector yet. Try turning off “Match sector” or choose a department filter.'
                    : 'No students found.',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(180),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Column(
              children: [
                for (final c in top) ...[
                  _CandidateRow(c: c),
                  if (c != top.last) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(
    BuildContext context, {
    required List<String> departments,
    required String sector,
  }) async {
    final hasSector = sector.trim().isNotEmpty;
    String? nextDept = selectedDepartment;
    bool nextMatch = matchSector;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Filter students',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    if (hasSector)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Match my company sector ($sector)'),
                        value: nextMatch,
                        onChanged: (v) => setModalState(() => nextMatch = v),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue:
                          (nextDept ?? '').trim().isEmpty ? null : nextDept,
                      isExpanded: true,
                      items: [
                        for (final d in departments)
                          DropdownMenuItem(
                            value: d,
                            child: Text(
                              d,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: (v) => setModalState(() => nextDept = v),
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (_, c) {
                        final isNarrow = c.maxWidth < 360;

                        final clearButton = TextButton(
                          onPressed: () => setModalState(() {
                            nextDept = null;
                            nextMatch = hasSector;
                          }),
                          child: const Text('Clear'),
                        );

                        final trailing = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                AppLocalizations.of(ctx).t(AppText.commonCancel),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                onChangeFilters(nextDept, nextMatch);
                                Navigator.of(ctx).pop();
                              },
                              child: Text(
                                AppLocalizations.of(ctx).t(AppText.commonConfirm),
                              ),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: clearButton,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: trailing,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            clearButton,
                            const Spacer(),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: trailing,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onClear});

  final IconData icon;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withAlpha(170)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClear,
            child: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.c});

  final TalentCandidate c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = c.fullName.trim().isEmpty ? 'Student' : c.fullName.trim();
    final dept = (c.department ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(160)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withAlpha(18),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (dept.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dept,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(170),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text(
                'Points',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '${c.totalPoints}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
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
