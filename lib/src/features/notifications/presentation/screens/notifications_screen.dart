import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all';
  bool _loading = true;
  String? _markingId;
  String? _loadedUserId;

  List<_NotificationItem> _items = const [];
  RealtimeChannel? _channel;

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseService.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);
    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    final user = auth?.user;
    final isLoggedIn = auth?.isAuthenticated ?? false;

    if (!isLoggedIn || user == null) {
      return _GuestView(title: 'Bildirimleri görmek için giriş yapmalısın.');
    }

    _ensureLoaded(user.id);

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final unreadCount = _items.where((e) => !e.isRead).length;
    final readCount = _items.where((e) => e.isRead).length;

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (_, c) {
                      final stacked = c.maxWidth < 640;
                      final titleRow = Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: const [
                          Icon(Icons.notifications, color: Color(0xFF6D28D9), size: 28),
                          Text(
                            'Bildirimler',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                          ),
                        ],
                      );

                      final action = unreadCount > 0
                          ? TextButton.icon(
                              onPressed: _markAllAsRead,
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Tümünü Okundu İşaretle'),
                            )
                          : const SizedBox.shrink();

                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            if (unreadCount > 0) ...[
                              const SizedBox(height: 8),
                              action,
                            ],
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          titleRow,
                          action,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFF6D28D9)),
                          Text(
                            '$unreadCount okunmamış bildirim',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  _FilterTabs(
                    filter: _filter,
                    total: _items.length,
                    unread: unreadCount,
                    read: readCount,
                    onTap: _setFilter,
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    _EmptyState(filter: _filter)
                  else
                    Column(
                      children: [
                        for (final item in _items)
                          _NotificationCard(
                            item: item,
                            marking: _markingId == item.id,
                            onMark: () => _markAsRead(item.id),
                            onDelete: () => _deleteNotification(item.id),
                            onOpen: item.actionUrl == null
                                ? null
                                : () => _openAction(item.actionUrl!),
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

  void _ensureLoaded(String uid) {
    if (_loadedUserId == uid) return;
    _loadedUserId = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtime(uid);
      _fetchNotifications(uid);
    });
  }

  void _setFilter(String filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _loading = true;
    });
    final uid = _loadedUserId;
    if (uid != null) _fetchNotifications(uid);
  }

  void _setupRealtime(String uid) {
    if (_channel != null) {
      SupabaseService.client.removeChannel(_channel!);
    }

    _channel = SupabaseService.client.channel('notifications');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final item = _NotificationItem.fromMap(payload.newRecord);
            if (item == null) return;
            if (!mounted) return;
            setState(() => _items = [item, ..._items]);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Yeni bildirim!')),
            );
          },
        )
        .subscribe();
  }

  Future<void> _fetchNotifications(String uid) async {
    setState(() => _loading = true);
    try {
      var query = SupabaseService.client
          .from('notifications')
          .select('*')
          .eq('user_id', uid);

      if (_filter == 'unread') {
        query = query.eq('is_read', false);
      } else if (_filter == 'read') {
        query = query.eq('is_read', true);
      }

      final rows = await query.order('created_at', ascending: false);
      final items = (rows as List)
          .map((e) => _NotificationItem.fromMap(e as Map<String, dynamic>))
          .whereType<_NotificationItem>()
          .toList();

      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirimler yüklenirken hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    setState(() => _markingId = id);
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);

      if (!mounted) return;
      setState(() {
        _items = _items
            .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _markingId = null);
    }
  }

  Future<void> _markAllAsRead() async {
    final ids = _items.where((e) => !e.isRead).map((e) => e.id).toList();
    if (ids.isEmpty) return;

    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .inFilter('id', ids);

      if (!mounted) return;
      setState(() => _items = _items.map((e) => e.copyWith(isRead: true)).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm bildirimler okundu olarak işaretlendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await SupabaseService.client.from('notifications').delete().eq('id', id);
      if (!mounted) return;
      setState(() => _items = _items.where((e) => e.id != id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirim silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silme işlemi başarısız: $e')),
      );
    }
  }

  void _openAction(String url) {
    if (!url.startsWith('/')) return;
    context.go(url);
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.filter,
    required this.total,
    required this.unread,
    required this.read,
    required this.onTap,
  });

  final String filter;
  final int total;
  final int unread;
  final int read;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _TabButton(
            label: 'Tümü ($total)',
            active: filter == 'all',
            onTap: () => onTap('all'),
          ),
          _TabButton(
            label: 'Okunmamış ($unread)',
            active: filter == 'unread',
            onTap: () => onTap('unread'),
          ),
          _TabButton(
            label: 'Okunmuş ($read)',
            active: filter == 'read',
            onTap: () => onTap('read'),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? const Color(0xFF6D28D9) : const Color(0xFF6B7280),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.marking,
    required this.onMark,
    required this.onDelete,
    this.onOpen,
  });

  final _NotificationItem item;
  final bool marking;
  final VoidCallback onMark;
  final VoidCallback onDelete;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.isRead ? const Color(0xFFE5E7EB) : const Color(0xFFD8B4FE)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(type: item.type, icon: item.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(item.message, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      item.timeAgo,
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                    if (item.actionUrl != null) ...[
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Color(0xFF9CA3AF))),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onOpen,
                        child: const Text('Detayları Gör →'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (!item.isRead)
                IconButton(
                  onPressed: marking ? null : onMark,
                  icon: const Icon(Icons.check),
                  color: const Color(0xFF10B981),
                ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.type, required this.icon});
  final String? type;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final color = _NotificationItem.colorForType(type);
    final iconData = _NotificationItem.iconFor(icon);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final text = filter == 'unread'
        ? 'Okunmamış bildiriminiz yok.'
        : filter == 'read'
            ? 'Okunmuş bildiriminiz yok.'
            : 'Henüz bildiriminiz yok.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_off_outlined, size: 44, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 46, color: Color(0xFF6B7280)),
              const SizedBox(height: 10),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.isRead,
    required this.createdAt,
    required this.actionUrl,
  });

  final String id;
  final String title;
  final String message;
  final String? type;
  final String? icon;
  final bool isRead;
  final DateTime createdAt;
  final String? actionUrl;

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt).inHours;
    if (diff < 1) return 'Az önce';
    if (diff < 24) return '$diff saat önce';
    if (diff < 48) return 'Dün';
    if (diff < 168) return '${(diff / 24).floor()} gün önce';
    final d = createdAt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  _NotificationItem copyWith({bool? isRead}) {
    return _NotificationItem(
      id: id,
      title: title,
      message: message,
      type: type,
      icon: icon,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actionUrl: actionUrl,
    );
  }

  static _NotificationItem? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return _NotificationItem(
      id: map['id']?.toString() ?? '',
      title: (map['title'] ?? '') as String,
      message: (map['message'] ?? '') as String,
      type: map['type'] as String?,
      icon: map['icon'] as String?,
      isRead: (map['is_read'] as bool?) ?? false,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      actionUrl: map['action_url'] as String?,
    );
  }

  static IconData iconFor(String? icon) {
    switch (icon) {
      case 'trophy':
        return Icons.emoji_events;
      case 'award':
        return Icons.workspace_premium;
      case 'check':
        return Icons.check_circle;
      case 'book':
        return Icons.menu_book_outlined;
      case 'calendar':
        return Icons.calendar_month;
      case 'briefcase':
        return Icons.work_outline;
      case 'info':
        return Icons.info_outline;
      case 'alert':
        return Icons.error_outline;
      case 'zap':
        return Icons.bolt_outlined;
      default:
        return Icons.notifications;
    }
  }

  static Color colorForType(String? type) {
    switch (type) {
      case 'points_earned':
        return const Color(0xFF16A34A);
      case 'course_completed':
        return const Color(0xFF2563EB);
      case 'application_accepted':
        return const Color(0xFF7C3AED);
      case 'application_rejected':
        return const Color(0xFFDC2626);
      case 'new_course':
        return const Color(0xFF4F46E5);
      case 'reminder':
        return const Color(0xFFD97706);
      case 'achievement':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
