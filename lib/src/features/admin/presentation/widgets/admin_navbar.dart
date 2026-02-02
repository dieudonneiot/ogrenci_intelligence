import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/admin_controller.dart';

class AdminNavbar extends ConsumerStatefulWidget {
  const AdminNavbar({super.key});

  @override
  ConsumerState<AdminNavbar> createState() => _AdminNavbarState();
}

class _AdminNavbarState extends ConsumerState<AdminNavbar> {
  bool _mobileOpen = false;

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(activeAdminProvider).valueOrNull;
    final isSuper = admin?.isSuperAdmin ?? false;

    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 900;
    final currentPath = GoRouterState.of(context).uri.path;

    final navItems = const <_AdminNavItem>[
      _AdminNavItem('Dashboard', Routes.adminDashboard, Icons.home_outlined),
      _AdminNavItem('Şirketler', Routes.adminCompanies, Icons.apartment_outlined),
      _AdminNavItem('Kullanıcılar', Routes.adminUsers, Icons.group_outlined),
      _AdminNavItem('İlanlar', Routes.adminJobs, Icons.work_outline),
      _AdminNavItem('Abonelikler', Routes.adminSubscriptions, Icons.credit_card_outlined),
      _AdminNavItem('Raporlar', Routes.adminReports, Icons.bar_chart_outlined),
    ];

    return Material(
      color: const Color(0xFF111827),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.go(Routes.adminDashboard),
                        child: Row(
                          children: [
                            const Icon(Icons.security, color: Color(0xFFA78BFA), size: 28),
                            const SizedBox(width: 10),
                            const Text(
                              'Admin Panel',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            if (isSuper) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'SUPER',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 24),
                        for (final item in navItems)
                          _NavLink(
                            item: item,
                            isActive: _isActive(currentPath, item.path),
                            onTap: () => context.go(item.path),
                          ),
                      ],
                      const Spacer(),
                      _NotificationsButton(),
                      const SizedBox(width: 12),
                      _ProfileMenu(
                        name: admin?.name.isNotEmpty == true ? admin!.name : 'Admin',
                        email: admin?.email,
                        onNavigate: (path) => context.go(path),
                        onLogout: () => _handleLogout(context),
                      ),
                      if (!isDesktop)
                        IconButton(
                          tooltip: _mobileOpen ? 'Kapat' : 'Menü',
                          onPressed: () => setState(() => _mobileOpen = !_mobileOpen),
                          icon: Icon(_mobileOpen ? Icons.close : Icons.menu, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isDesktop)
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: _mobileOpen
                  ? Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F2937),
                        border: Border(top: BorderSide(color: Color(0xFF374151))),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            children: [
                              for (final item in navItems)
                                _MobileNavLink(
                                  item: item,
                                  isActive: _isActive(currentPath, item.path),
                                  onTap: () {
                                    setState(() => _mobileOpen = false);
                                    context.go(item.path);
                                  },
                                ),
                              const SizedBox(height: 8),
                              _MobileNavLink(
                                item: const _AdminNavItem('Çıkış Yap', Routes.home, Icons.logout),
                                isActive: false,
                                onTap: () => _handleLogout(context),
                                danger: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  bool _isActive(String currentPath, String target) {
    if (currentPath == target) return true;
    return currentPath.startsWith('$target/');
  }

  Future<void> _handleLogout(BuildContext context) async {
    final err = await ref.read(authActionLoadingProvider.notifier).signOut();
    if (!context.mounted) return;
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılamadı: $err')),
      );
      return;
    }
    context.go(Routes.home);
  }
}

class _AdminNavItem {
  const _AdminNavItem(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _AdminNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1F2937) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 16, color: isActive ? Colors.white : const Color(0xFFD1D5DB)),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFFD1D5DB),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavLink extends StatelessWidget {
  const _MobileNavLink({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.danger = false,
  });

  final _AdminNavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFFCA5A5)
        : isActive
            ? Colors.white
            : const Color(0xFFD1D5DB);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none, color: Color(0xFFD1D5DB)),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.name,
    required this.email,
    required this.onNavigate,
    required this.onLogout,
  });

  final String name;
  final String? email;
  final void Function(String path) onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ProfileAction>(
      tooltip: 'Profil Menüsü',
      offset: const Offset(0, 12),
      onSelected: (value) async {
        switch (value) {
          case _ProfileAction.profile:
            onNavigate(Routes.adminProfile);
            return;
          case _ProfileAction.settings:
            onNavigate(Routes.adminSettings);
            return;
          case _ProfileAction.logs:
            onNavigate(Routes.adminLogs);
            return;
          case _ProfileAction.logout:
            await onLogout();
            return;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_ProfileAction>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (email != null && email!.isNotEmpty)
                Text(email!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.profile,
          child: _ProfileMenuRow(icon: Icons.person_outline, label: 'Profil'),
        ),
        const PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.settings,
          child: _ProfileMenuRow(icon: Icons.settings_outlined, label: 'Ayarlar'),
        ),
        const PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.logs,
          child: _ProfileMenuRow(icon: Icons.receipt_long_outlined, label: 'İşlem Kayıtları'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.logout,
          child: _ProfileMenuRow(icon: Icons.logout, label: 'Çıkış Yap', danger: true),
        ),
      ],
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}

enum _ProfileAction { profile, settings, logs, logout }

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF374151);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
