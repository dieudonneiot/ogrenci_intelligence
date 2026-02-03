import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../presentation/controllers/admin_controller.dart';
import '../widgets/admin_layout.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _loading = true;
  _AdminStats _stats = const _AdminStats();
  List<_AdminActivity> _activities = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = SupabaseService.client;

      final futures = await Future.wait<dynamic>([
        client.from('profiles').select('id'),
        client.from('companies').select('approval_status'),
        client.from('jobs').select('id').eq('is_active', true),
        client.from('internships').select('id').eq('is_active', true),
        client.from('company_subscriptions').select('plan_type, ends_at, is_active'),
        client.from('subscription_plans').select('slug, name, price_monthly, price_yearly'),
        client
            .from('admin_logs')
            .select('id, action_type, created_at, admins(name)')
            .order('created_at', ascending: false)
            .limit(10),
      ]);

      final profiles = (futures[0] as List).cast<dynamic>();
      final companies = (futures[1] as List).cast<dynamic>();
      final jobs = (futures[2] as List).cast<dynamic>();
      final internships = (futures[3] as List).cast<dynamic>();
      final subscriptions = (futures[4] as List).cast<dynamic>();
      final plans = (futures[5] as List).cast<dynamic>();
      final logs = (futures[6] as List).cast<dynamic>();

      final pendingCompanies = companies.where((c) {
        final map = c as Map<String, dynamic>;
        return (map['approval_status'] ?? '').toString() == 'pending';
      }).length;

      final planBySlug = <String, _PlanPrice>{};
      for (final p in plans) {
        final map = p as Map<String, dynamic>;
        final slug = (map['slug'] ?? '').toString();
        final name = (map['name'] ?? '').toString();
        final monthly = _toInt(map['price_monthly']);
        final yearly = _toInt(map['price_yearly']);
        if (slug.isNotEmpty) {
          planBySlug[slug] = _PlanPrice(monthly: monthly, yearly: yearly, name: name);
        }
        if (name.isNotEmpty && !planBySlug.containsKey(name)) {
          planBySlug[name] = _PlanPrice(monthly: monthly, yearly: yearly, name: name);
        }
      }

      var activeSubs = 0;
      var monthlyRevenue = 0;
      final now = DateTime.now();

      for (final s in subscriptions) {
        final map = s as Map<String, dynamic>;
        final isActive = map['is_active'] == true;
        if (!isActive) continue;

        final endsAt = _parseDate(map['ends_at']);
        if (endsAt != null && endsAt.isBefore(now)) continue;

        activeSubs += 1;
        final planType = (map['plan_type'] ?? '').toString();
        final plan = planBySlug[planType];
        if (plan != null) {
          monthlyRevenue += plan.monthly;
        }
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toUtc();
      final todayRows = await client
          .from('profiles')
          .select('id')
          .gte('created_at', startOfDay.toIso8601String());

      final todayRegs = (todayRows as List).length;

      final activities = logs.map((row) {
        final map = row as Map<String, dynamic>;
        final admin = (map['admins'] as Map?)?.cast<String, dynamic>();
        return _AdminActivity(
          id: (map['id'] ?? '').toString(),
          actionType: (map['action_type'] ?? '').toString(),
          createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
          adminName: (admin?['name'] ?? 'Admin').toString(),
        );
      }).toList();

      _stats = _AdminStats(
        totalUsers: profiles.length,
        totalCompanies: companies.length,
        pendingCompanies: pendingCompanies,
        totalJobs: jobs.length,
        totalInternships: internships.length,
        activeSubscriptions: activeSubs,
        monthlyRevenue: monthlyRevenue,
        todayRegistrations: todayRegs,
      );
      _activities = activities;
    } catch (e) {
      _error = e.toString();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(activeAdminProvider).valueOrNull;
    final adminName = admin?.name.isNotEmpty == true ? admin!.name : l10n.t(AppText.adminRoleAdmin);
    final isSuper = admin?.isSuperAdmin ?? false;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(l10n.t(AppText.adminDashboardLoadFailedTitle),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _fetchDashboard,
                child: Text(l10n.t(AppText.retry)),
              ),
            ],
          ),
        ),
      );
    }

    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.security_outlined,
        title: l10n.t(AppText.adminDashboardTitle),
        subtitle: l10n.adminDashboardSubtitleWithName(adminName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isSuper ? l10n.t(AppText.adminRoleSuper) : l10n.t(AppText.adminRoleAdmin),
            style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w800),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsGrid(stats: _stats),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (!wide) {
                return Column(
                  children: [
                    _PendingCard(
                      pending: _stats.pendingCompanies,
                      onTap: () => context.go('${Routes.adminCompanies}?status=pending'),
                    ),
                    const SizedBox(height: 16),
                    const _QuickLinks(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PendingCard(
                      pending: _stats.pendingCompanies,
                      onTap: () => context.go('${Routes.adminCompanies}?status=pending'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: _QuickLinks()),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _RecentActivities(activities: _activities),
        ],
      ),
    );
  }
}

class _AdminStats {
  const _AdminStats({
    this.totalUsers = 0,
    this.totalCompanies = 0,
    this.pendingCompanies = 0,
    this.totalJobs = 0,
    this.totalInternships = 0,
    this.activeSubscriptions = 0,
    this.monthlyRevenue = 0,
    this.todayRegistrations = 0,
  });

  final int totalUsers;
  final int totalCompanies;
  final int pendingCompanies;
  final int totalJobs;
  final int totalInternships;
  final int activeSubscriptions;
  final int monthlyRevenue;
  final int todayRegistrations;
}

class _AdminActivity {
  const _AdminActivity({
    required this.id,
    required this.actionType,
    required this.createdAt,
    required this.adminName,
  });

  final String id;
  final String actionType;
  final DateTime createdAt;
  final String adminName;
}

class _PlanPrice {
  const _PlanPrice({
    required this.monthly,
    required this.yearly,
    required this.name,
  });

  final int monthly;
  final int yearly;
  final String name;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final _AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = <Widget>[
      _StatCard(
        title: l10n.t(AppText.adminStatTotalUsersTitle),
        value: stats.totalUsers.toString(),
        subtitle: l10n.adminStatTotalUsersSubtitleToday(stats.todayRegistrations),
        subtitleColor: const Color(0xFF16A34A),
        icon: Icons.group_outlined,
        iconColor: const Color(0xFF2563EB),
      ),
      _StatCard(
        title: l10n.t(AppText.adminStatCompaniesTitle),
        value: stats.totalCompanies.toString(),
        subtitle: l10n.adminStatCompaniesSubtitlePending(stats.pendingCompanies),
        subtitleColor: const Color(0xFFF97316),
        icon: Icons.apartment_outlined,
        iconColor: const Color(0xFF7C3AED),
      ),
      _StatCard(
        title: l10n.t(AppText.adminStatActiveListingsTitle),
        value: (stats.totalJobs + stats.totalInternships).toString(),
        subtitle: l10n.adminStatActiveListingsSubtitle(jobs: stats.totalJobs, internships: stats.totalInternships),
        subtitleColor: const Color(0xFF6B7280),
        icon: Icons.work_outline,
        iconColor: const Color(0xFF16A34A),
      ),
      _StatCard(
        title: l10n.t(AppText.adminStatMonthlyRevenueTitle),
        value: '₺${_formatNumber(stats.monthlyRevenue)}',
        subtitle: l10n.adminStatMonthlyRevenueSubtitle(stats.activeSubscriptions),
        subtitleColor: const Color(0xFF16A34A),
        icon: Icons.credit_card_outlined,
        iconColor: const Color(0xFFF59E0B),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((c) => SizedBox(width: (constraints.maxWidth - 14) / 2, child: c))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          Icon(icon, size: 36, color: iconColor),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.pending, required this.onTap});
  final int pending;
  final VoidCallback onTap;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFF97316)),
              const SizedBox(width: 8),
              Text(l10n.t(AppText.adminCompanyApprovalsTitle),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          if (pending > 0) ...[
            Text('$pending', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFFF97316))),
            const SizedBox(height: 6),
            Text(l10n.t(AppText.adminCompanyApprovalsSubtitle),
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.trending_up, size: 18),
              label: Text(l10n.t(AppText.adminReviewCompanies)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            ),
          ] else
            Text(l10n.t(AppText.adminCompanyApprovalsEmpty),
                style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t(AppText.adminQuickAccessTitle),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickLinkTile(
                icon: Icons.apartment_outlined,
                label: l10n.t(AppText.adminNavCompanies),
                color: const Color(0xFF7C3AED),
                onTap: () => context.go(Routes.adminCompanies),
              ),
              _QuickLinkTile(
                icon: Icons.group_outlined,
                label: l10n.t(AppText.adminNavUsers),
                color: const Color(0xFF2563EB),
                onTap: () => context.go(Routes.adminUsers),
              ),
              _QuickLinkTile(
                icon: Icons.work_outline,
                label: l10n.t(AppText.adminNavJobs),
                color: const Color(0xFF16A34A),
                onTap: () => context.go(Routes.adminJobs),
              ),
              _QuickLinkTile(
                icon: Icons.credit_card_outlined,
                label: l10n.t(AppText.adminNavSubscriptions),
                color: const Color(0xFFF59E0B),
                onTap: () => context.go(Routes.adminSubscriptions),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivities extends StatelessWidget {
  const _RecentActivities({required this.activities});
  final List<_AdminActivity> activities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ml10n = MaterialLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(l10n.t(AppText.adminRecentActivitiesTitle),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Text(l10n.t(AppText.adminRecentActivitiesEmpty),
                style: const TextStyle(color: Color(0xFF6B7280)))
          else
            Column(
              children: activities
                  .map(
                    (a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _ActivityIcon(actionType: a.actionType),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_activityText(l10n, a.actionType),
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${a.adminName} • ${_formatTimeAgo(l10n, ml10n, a.createdAt)}',
                                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.actionType});
  final String actionType;

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.bolt_outlined;
    Color color = const Color(0xFF2563EB);

    switch (actionType) {
      case 'company_approve':
        icon = Icons.check_circle_outline;
        color = const Color(0xFF16A34A);
        break;
      case 'company_reject':
        icon = Icons.cancel_outlined;
        color = const Color(0xFFDC2626);
        break;
      case 'job_delete':
        icon = Icons.work_outline;
        color = const Color(0xFF6B7280);
        break;
      default:
        break;
    }

    return Icon(icon, color: color);
  }
}

String _activityText(AppLocalizations l10n, String actionType) {
  switch (actionType) {
    case 'company_approve':
      return l10n.t(AppText.adminActivityCompanyApproved);
    case 'company_reject':
      return l10n.t(AppText.adminActivityCompanyRejected);
    case 'job_delete':
      return l10n.t(AppText.adminActivityJobDeleted);
    case 'user_ban':
      return l10n.t(AppText.adminActivityUserBanned);
    default:
      return l10n.t(AppText.adminActivityUnknown);
  }
}

String _formatTimeAgo(AppLocalizations l10n, MaterialLocalizations ml10n, DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 60) return l10n.adminTimeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.adminTimeAgoHours(diff.inHours);
  if (diff.inDays < 7) return l10n.adminTimeAgoDays(diff.inDays);
  return ml10n.formatShortDate(date);
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

DateTime? _parseDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

String _formatNumber(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    buffer.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
