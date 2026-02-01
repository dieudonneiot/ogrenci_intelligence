import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../presentation/controllers/admin_controller.dart';
import '../widgets/admin_layout.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<_AdminUser> _users = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select('*, job_applications(count), internship_applications(count)')
          .order('created_at', ascending: false);

      _users = (rows as List)
          .map((row) => _AdminUser.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showUserDetail(_AdminUser user) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcı Detayları'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Ad Soyad', value: user.fullName ?? '-'),
              _DetailRow(label: 'Email', value: user.email ?? '-'),
              _DetailRow(label: 'Telefon', value: user.phone ?? '-'),
              _DetailRow(label: 'Üniversite', value: user.university ?? '-'),
              _DetailRow(label: 'Bölüm', value: user.department ?? '-'),
              _DetailRow(label: 'Kayıt Tarihi', value: user.createdAtText),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _banUser(_AdminUser user) async {
    final ok = await _confirm(
      title: 'Kullanıcıyı Engelle',
      message: 'Bu kullanıcıyı engellemek istediğinizden emin misiniz?',
    );
    if (!ok) return;

    try {
      await SupabaseService.client.from('profiles').update({
        'is_banned': true,
        'banned_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);

      await ref.read(adminActionControllerProvider.notifier).logAction(
            actionType: 'user_ban',
            targetType: 'user',
            targetId: user.id,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi')));
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı engellenemedi: $e')),
      );
    }
  }

  Future<void> _unbanUser(_AdminUser user) async {
    try {
      await SupabaseService.client.from('profiles').update({
        'is_banned': false,
        'banned_at': null,
      }).eq('id', user.id);

      await ref.read(adminActionControllerProvider.notifier).logAction(
            actionType: 'user_unban',
            targetType: 'user',
            targetId: user.id,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Engel kaldırıldı')));
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Engel kaldırılamadı: $e')),
      );
    }
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      if (query.isEmpty) return true;
      return (u.fullName ?? '').toLowerCase().contains(query) ||
          (u.email ?? '').toLowerCase().contains(query) ||
          (u.university ?? '').toLowerCase().contains(query);
    }).toList();

    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.group_outlined,
        title: 'Kullanıcı Yönetimi',
        trailing: Text('Toplam: ${_users.length} kullanıcı', style: const TextStyle(color: Color(0xFF6B7280))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ad, email veya üniversite ara...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_error != null)
            _ErrorState(text: _error!, onRetry: _fetchUsers)
          else if (filtered.isEmpty)
            const _EmptyState()
          else
            _UsersTable(
              users: filtered,
              onOpen: _showUserDetail,
              onBan: _banUser,
              onUnban: _unbanUser,
            ),
        ],
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.onOpen,
    required this.onBan,
    required this.onUnban,
  });

  final List<_AdminUser> users;
  final void Function(_AdminUser) onOpen;
  final void Function(_AdminUser) onBan;
  final void Function(_AdminUser) onUnban;

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
            DataColumn(label: Text('Kullanıcı')),
            DataColumn(label: Text('Eğitim')),
            DataColumn(label: Text('Başvurular')),
            DataColumn(label: Text('Kayıt Tarihi')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: users.map((user) {
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(user.email ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.university ?? '-', style: const TextStyle(fontSize: 12)),
                      Text(user.department ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                DataCell(Text('${user.applicationsCount} başvuru', style: const TextStyle(fontSize: 12))),
                DataCell(Text(user.createdAtDate, style: const TextStyle(fontSize: 12))),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => onOpen(user),
                        icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF7C3AED)),
                      ),
                      if (user.isBanned)
                        IconButton(
                          onPressed: () => onUnban(user),
                          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                        )
                      else
                        IconButton(
                          onPressed: () => onBan(user),
                          icon: const Icon(Icons.block, color: Color(0xFFDC2626)),
                        ),
                    ],
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
          Icon(Icons.group_outlined, size: 56, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text('Kullanıcı bulunamadı', style: TextStyle(fontWeight: FontWeight.w800)),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AdminUser {
  const _AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.department,
    required this.university,
    required this.phone,
    required this.createdAt,
    required this.isBanned,
    required this.applicationsCount,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? department;
  final String? university;
  final String? phone;
  final DateTime? createdAt;
  final bool isBanned;
  final int applicationsCount;

  String get createdAtDate {
    final dt = createdAt;
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String get createdAtText {
    final dt = createdAt;
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  factory _AdminUser.fromMap(Map<String, dynamic> map) {
    final jobCount = _extractCount(map['job_applications']);
    final internshipCount = _extractCount(map['internship_applications']);

    return _AdminUser(
      id: (map['id'] ?? '').toString(),
      email: (map['email'] as String?)?.trim(),
      fullName: (map['full_name'] as String?)?.trim(),
      department: (map['department'] as String?)?.trim(),
      university: (map['university'] as String?)?.trim(),
      phone: (map['phone'] as String?)?.trim(),
      createdAt: _parseDate(map['created_at']),
      isBanned: map['is_banned'] == true,
      applicationsCount: jobCount + internshipCount,
    );
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
