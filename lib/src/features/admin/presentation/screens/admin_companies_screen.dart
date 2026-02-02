import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../presentation/controllers/admin_controller.dart';
import '../widgets/admin_layout.dart';

class AdminCompaniesScreen extends ConsumerStatefulWidget {
  const AdminCompaniesScreen({super.key});

  @override
  ConsumerState<AdminCompaniesScreen> createState() => _AdminCompaniesScreenState();
}

class _AdminCompaniesScreenState extends ConsumerState<AdminCompaniesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  String _filterStatus = 'all';
  List<_AdminCompany> _companies = const [];
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final status = GoRouterState.of(context).uri.queryParameters['status'] ?? 'all';
    if (status != _filterStatus) {
      _filterStatus = status;
      if (_initialized) {
        _fetchCompanies();
        return;
      }
    }
    if (!_initialized) {
      _initialized = true;
      _fetchCompanies();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var query = SupabaseService.client
          .from('companies')
          .select(
            'id, name, logo_url, sector, email, city, phone, employee_count, '
            'founded_year, website, description, approval_status, rejection_reason, '
            'banned_at, created_at, '
            'company_subscriptions(id, plan_type, ends_at, is_active), '
            'jobs(count), internships(count)',
          );

      if (_filterStatus != 'all') {
        query = query.eq('approval_status', _filterStatus);
      }

      final rows = await query.order('created_at', ascending: false);

      final list = (rows as List)
          .map((row) => _AdminCompany.fromMap(row as Map<String, dynamic>))
          .toList();

      _companies = list;
    } catch (e) {
      _error = e.toString();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _updateStatusFilter(String status) {
    setState(() => _filterStatus = status);
    final params = <String, String>{};
    if (status != 'all') params['status'] = status;
    context.go(Uri(path: Routes.adminCompanies, queryParameters: params).toString());
    _fetchCompanies();
  }

  Future<void> _showCompanyDetail(_AdminCompany company) async {
    var rejectionReason = company.rejectionReason ?? '';
    var actionLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runAction(Future<String?> Function() action) async {
              setDialogState(() => actionLoading = true);
              final err = await action();
              if (!context.mounted) return;
              setDialogState(() => actionLoading = false);
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
                return;
              }
              Navigator.of(context).pop();
              await _fetchCompanies();
            }

            return AlertDialog(
              title: const Text('Şirket Detayları'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CompanyAvatar(logoUrl: company.logoUrl, size: 64),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(company.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(company.sector ?? '-', style: const TextStyle(color: Color(0xFF6B7280))),
                                const SizedBox(height: 8),
                                _StatusBadge(status: company.approvalStatus),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailGrid(items: [
                        _DetailItem(label: 'Email', value: company.email ?? '-'),
                        _DetailItem(label: 'Telefon', value: company.phone ?? '-'),
                        _DetailItem(label: 'Şehir', value: company.city ?? '-'),
                        _DetailItem(label: 'Çalışan Sayısı', value: company.employeeCount ?? '-'),
                        _DetailItem(label: 'Kuruluş Yılı', value: company.foundedYear?.toString() ?? '-'),
                        _DetailItem(label: 'Website', value: company.website ?? '-'),
                      ]),
                      if (company.description != null && company.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Açıklama', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(company.description!, style: const TextStyle(color: Color(0xFF6B7280))),
                      ],
                      if (company.rejectionReason != null && company.rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Red Nedeni', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                              const SizedBox(height: 6),
                              Text(company.rejectionReason!, style: const TextStyle(color: Color(0xFF7F1D1D))),
                            ],
                          ),
                        ),
                      ],
                      if (company.approvalStatus == 'pending') ...[
                        const SizedBox(height: 16),
                        const Text('Red Nedeni (Reddetmek için zorunlu)', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (v) => rejectionReason = v,
                          decoration: InputDecoration(
                            hintText: 'Şirketin neden reddedildiğini açıklayın...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
                if (company.approvalStatus == 'pending') ...[
                  ElevatedButton.icon(
                    onPressed: actionLoading
                        ? null
                        : () => runAction(() => _approveCompany(company)),
                    icon: actionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  ),
                  ElevatedButton.icon(
                    onPressed: actionLoading || rejectionReason.trim().isEmpty
                        ? null
                        : () => runAction(() => _rejectCompany(company, rejectionReason.trim())),
                    icon: actionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('Reddet'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                  ),
                ],
                if (company.approvalStatus == 'approved')
                  ElevatedButton.icon(
                    onPressed: actionLoading
                        ? null
                        : () async {
                            final ok = await _confirmBan(dialogContext);
                            if (!ok) return;
                            await runAction(() => _banCompany(company));
                          },
                    icon: actionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.block),
                    label: const Text('Şirketi Engelle'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmBan(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şirketi Engelle'),
        content: const Text('Bu şirketi engellemek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _approveCompany(_AdminCompany company) async {
    try {
      final admin = await ref.read(activeAdminProvider.future);
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = <String, dynamic>{
        'approval_status': 'approved',
        'approved_at': now,
        if (admin?.id.isNotEmpty == true) 'approved_by': admin!.id,
      };

      await SupabaseService.client.from('companies').update(payload).eq('id', company.id);

      await ref.read(adminActionControllerProvider.notifier).logAction(
            actionType: 'company_approve',
            targetType: 'company',
            targetId: company.id,
            details: {'company_name': company.name},
          );
      return null;
    } catch (e) {
      return 'Onaylama işlemi başarısız: $e';
    }
  }

  Future<String?> _rejectCompany(_AdminCompany company, String reason) async {
    try {
      final admin = await ref.read(activeAdminProvider.future);
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = <String, dynamic>{
        'approval_status': 'rejected',
        'rejection_reason': reason,
        'approved_at': now,
        if (admin?.id.isNotEmpty == true) 'approved_by': admin!.id,
      };

      await SupabaseService.client.from('companies').update(payload).eq('id', company.id);

      await ref.read(adminActionControllerProvider.notifier).logAction(
            actionType: 'company_reject',
            targetType: 'company',
            targetId: company.id,
            details: {'company_name': company.name, 'reason': reason},
          );
      return null;
    } catch (e) {
      return 'Reddetme işlemi başarısız: $e';
    }
  }

  Future<String?> _banCompany(_AdminCompany company) async {
    try {
      await Future.wait<void>([
        SupabaseService.client.from('jobs').update({'is_active': false}).eq('company_id', company.id),
        SupabaseService.client.from('internships').update({'is_active': false}).eq('company_id', company.id),
      ]);

      await SupabaseService.client.from('companies').update({
        'approval_status': 'banned',
        'banned_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', company.id);

      await ref.read(adminActionControllerProvider.notifier).logAction(
            actionType: 'company_ban',
            targetType: 'company',
            targetId: company.id,
            details: {'company_name': company.name},
          );
      return null;
    } catch (e) {
      return 'Engelleme işlemi başarısız: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _companies.where((c) {
      final query = _searchCtrl.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          (c.email ?? '').toLowerCase().contains(query) ||
          (c.city ?? '').toLowerCase().contains(query);
    }).toList();

    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.apartment_outlined,
        title: 'Şirket Yönetimi',
        trailing: Text('Toplam: ${_companies.length}', style: const TextStyle(color: Color(0xFF6B7280))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FiltersBar(
            controller: _searchCtrl,
            status: _filterStatus,
            onStatusChanged: _updateStatusFilter,
            onSearchChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_error != null)
            _ErrorState(text: _error!, onRetry: _fetchCompanies)
          else if (filtered.isEmpty)
            const _EmptyState()
          else
            _CompaniesTable(
              companies: filtered,
              onOpen: _showCompanyDetail,
            ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.controller,
    required this.status,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final statuses = const ['all', 'pending', 'approved', 'rejected', 'banned'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Şirket adı, email veya şehir ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: statuses.map((s) {
              final active = s == status;
              return OutlinedButton(
                onPressed: () => onStatusChanged(s),
                style: OutlinedButton.styleFrom(
                  backgroundColor: active ? const Color(0xFF7C3AED) : const Color(0xFFF3F4F6),
                  foregroundColor: active ? Colors.white : const Color(0xFF374151),
                  side: BorderSide(color: active ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB)),
                ),
                child: Text(_statusLabel(s)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String value) {
    switch (value) {
      case 'pending':
        return 'Bekleyen';
      case 'approved':
        return 'Onaylı';
      case 'rejected':
        return 'Reddedilen';
      case 'banned':
        return 'Engelli';
      case 'all':
      default:
        return 'Tümü';
    }
  }
}

class _CompaniesTable extends StatelessWidget {
  const _CompaniesTable({
    required this.companies,
    required this.onOpen,
  });

  final List<_AdminCompany> companies;
  final void Function(_AdminCompany) onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Şirket')),
            DataColumn(label: Text('İletişim')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Abonelik')),
            DataColumn(label: Text('İlanlar')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: companies.map((company) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      _CompanyAvatar(logoUrl: company.logoUrl, size: 40),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(company.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(company.sector ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company.email ?? '-', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(company.city ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(_StatusBadge(status: company.approvalStatus)),
                DataCell(
                  company.activeSubscription == null
                      ? const Text('Abonelik yok', style: TextStyle(color: Color(0xFF6B7280)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(company.activeSubscription!.planLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'Bitiş: ${company.activeSubscription!.endsAtText}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                ),
                DataCell(
                  Text('${company.totalJobs} iş, ${company.totalInternships} staj', style: const TextStyle(fontSize: 12)),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => onOpen(company),
                    child: const Text('Detay'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.apartment_outlined, size: 56, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text('Şirket bulunamadı', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Arama kriterlerinize uygun şirket bulunmuyor',
              style: TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'approved':
        return _Pill(icon: Icons.check_circle_outline, text: 'Onaylı', fg: const Color(0xFF15803D), bg: const Color(0xFFDCFCE7));
      case 'pending':
        return _Pill(icon: Icons.schedule, text: 'Bekliyor', fg: const Color(0xFFB45309), bg: const Color(0xFFFEF3C7));
      case 'rejected':
        return _Pill(icon: Icons.cancel_outlined, text: 'Reddedildi', fg: const Color(0xFFB91C1C), bg: const Color(0xFFFEE2E2));
      case 'banned':
        return _Pill(icon: Icons.block, text: 'Engelli', fg: Colors.white, bg: const Color(0xFF111827));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.fg, required this.bg});
  final IconData icon;
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({required this.logoUrl, required this.size});
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.apartment_outlined, color: Color(0xFF6B7280)),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(item.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DetailItem {
  const _DetailItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _AdminCompany {
  const _AdminCompany({
    required this.id,
    required this.name,
    required this.sector,
    required this.logoUrl,
    required this.email,
    required this.city,
    required this.phone,
    required this.employeeCount,
    required this.foundedYear,
    required this.website,
    required this.description,
    required this.approvalStatus,
    required this.rejectionReason,
    required this.bannedAt,
    required this.createdAt,
    required this.activeSubscription,
    required this.totalJobs,
    required this.totalInternships,
  });

  final String id;
  final String name;
  final String? sector;
  final String? logoUrl;
  final String? email;
  final String? city;
  final String? phone;
  final String? employeeCount;
  final int? foundedYear;
  final String? website;
  final String? description;
  final String approvalStatus;
  final String? rejectionReason;
  final DateTime? bannedAt;
  final DateTime? createdAt;
  final _CompanySubscription? activeSubscription;
  final int totalJobs;
  final int totalInternships;

  factory _AdminCompany.fromMap(Map<String, dynamic> map) {
    final subs = (map['company_subscriptions'] as List?)?.cast<dynamic>() ?? const [];
    final activeSub = _CompanySubscription.pickActive(subs);

    final jobsCount = _extractCount(map['jobs']);
    final internshipsCount = _extractCount(map['internships']);
    final foundedValue = _toInt(map['founded_year']);

    return _AdminCompany(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      sector: (map['sector'] as String?)?.trim(),
      logoUrl: (map['logo_url'] as String?)?.trim(),
      email: (map['email'] as String?)?.trim(),
      city: (map['city'] as String?)?.trim(),
      phone: (map['phone'] as String?)?.trim(),
      employeeCount: (map['employee_count'] as String?)?.trim(),
      foundedYear: foundedValue == 0 ? null : foundedValue,
      website: (map['website'] as String?)?.trim(),
      description: (map['description'] as String?)?.trim(),
      approvalStatus: (map['approval_status'] ?? 'pending').toString(),
      rejectionReason: (map['rejection_reason'] as String?)?.trim(),
      bannedAt: _parseDate(map['banned_at']),
      createdAt: _parseDate(map['created_at']),
      activeSubscription: activeSub,
      totalJobs: jobsCount,
      totalInternships: internshipsCount,
    );
  }
}

class _CompanySubscription {
  const _CompanySubscription({
    required this.planType,
    required this.endsAt,
  });

  final String planType;
  final DateTime? endsAt;

  String get planLabel {
    if (planType.isEmpty) return 'Plan';
    return planType[0].toUpperCase() + planType.substring(1);
  }

  String get endsAtText {
    final dt = endsAt;
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  static _CompanySubscription? pickActive(List<dynamic> rows) {
    final now = DateTime.now();
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      if (map['is_active'] != true) continue;
      final endsAt = _parseDate(map['ends_at']);
      if (endsAt != null && endsAt.isBefore(now)) continue;
      final planType = (map['plan_type'] ?? '').toString();
      return _CompanySubscription(planType: planType, endsAt: endsAt);
    }
    return null;
  }
}

int _extractCount(dynamic value) {
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is Map) {
      final map = first.cast<String, dynamic>();
      return _toInt(map['count']);
    }
  }
  if (value is Map) {
    final map = value.cast<String, dynamic>();
    return _toInt(map['count']);
  }
  return 0;
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
