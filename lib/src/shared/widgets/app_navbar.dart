import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

class AppNavbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const AppNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  ConsumerState<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends ConsumerState<AppNavbar> {
  bool _mobileOpen = false;

  void _toggleMobile() => setState(() => _mobileOpen = !_mobileOpen);
  void _closeMobile() => setState(() => _mobileOpen = false);

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);
    final auth = authAsync.value;

    final isLoading = authAsync.isLoading;
    final isLoggedIn = (!isLoading) && (auth?.isAuthenticated ?? false);
    final userType = auth?.userType ?? UserType.student;

    // React Navbar: company sees company menu; else student menu
    final isCompany = isLoggedIn && userType == UserType.company;
    final isAdmin = isLoggedIn && userType == UserType.admin;

    // In React: logo click redirects by role (company -> company dashboard else home)
    final logoTarget = isCompany
        ? Routes.companyDashboard
        : isAdmin
            ? Routes.adminDashboard
            : Routes.home;

    final menuItems = isCompany
        ? const <_NavItem>[
            _NavItem("İlanlarım", Routes.companyJobs),
            _NavItem("Staj Yönetimi", Routes.companyInternships),
            _NavItem("Başvurular", Routes.companyApplications),
            _NavItem("Raporlar", Routes.companyReports),
          ]
        : const <_NavItem>[
            _NavItem("Anasayfa", Routes.home),
            _NavItem("Kurslar", Routes.courses),
            _NavItem("İş İlanları", Routes.jobs),
            _NavItem("Stajlar", Routes.internships),
          ];

    // Dropdown items
    final dropdownItems = isCompany
        ? const <_NavItem>[
            _NavItem("Şirket Profili", Routes.companyProfile, icon: Icons.business),
            _NavItem("Dashboard", Routes.companyDashboard, icon: Icons.dashboard_outlined),
            _NavItem("Paketler ve Fiyatlar", Routes.companyPricing, icon: Icons.credit_card),
            // NOTE: you don't currently have Routes.companySettings in your routes.dart
            // If you add it later, you can put it here.
          ]
        : const <_NavItem>[
            _NavItem("Profilim", Routes.profile, icon: Icons.person_outline),
            _NavItem("Dashboard", Routes.dashboard, icon: Icons.dashboard_outlined),
            _NavItem("Başvurularım", Routes.applications, icon: Icons.article_outlined),
            _NavItem("Favorilerim", Routes.favorites, icon: Icons.favorite_border),
            _NavItem("Bildirimler", Routes.notifications, icon: Icons.notifications_none),
            _NavItem("Ayarlar", Routes.settings, icon: Icons.settings_outlined),
          ];

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Material(
      color: Colors.white,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar (sticky look)
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)), // gray-200
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  children: [
                    // Logo + Brand
                    InkWell(
                      onTap: () {
                        _closeMobile();
                        context.go(logoTarget);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          if (isCompany)
                            Icon(Icons.apartment, size: 34, color: const Color(0xFF7C3AED))
                          else
                            const Icon(Icons.school, size: 34, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 10),
                          if (isDesktop)
                            Text(
                              isCompany ? "İşletme Paneli" : "Öğrenci İntelligence",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED),
                                letterSpacing: -0.2,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Desktop menu
                    if (isDesktop) ...[
                      for (final item in menuItems)
                        _NavLink(
                          label: item.label,
                          onTap: () {
                            _closeMobile();
                            context.go(item.path);
                          },
                        ),

                      const SizedBox(width: 10),

                      // Not logged in: show company auth button (React behavior)
                      if (!isLoggedIn && !isLoading) ...[
                        _PrimaryPillButton(
                          label: "İşletme Girişi",
                          onTap: () {
                            _closeMobile();
                            context.go(Routes.companyAuth);
                          },
                        ),
                        const SizedBox(width: 10),
                      ],

                      if (isLoading)
                        Container(
                          width: 80,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )
                      else if (!isLoggedIn) ...[
                        _PrimaryPillButton(
                          label: "Öğrenci Girişi",
                          onTap: () {
                            _closeMobile();
                            context.go(Routes.login);
                          },
                        ),
                        const SizedBox(width: 10),
                        _PrimaryPillButton(
                          label: "Kayıt Ol",
                          onTap: () {
                            _closeMobile();
                            context.go(Routes.register);
                          },
                        ),
                      ] else ...[
                        // Company: "Yeni İlan"
                        if (isCompany) ...[
                          _PrimaryPillButton(
                            label: "Yeni İlan",
                            onTap: () {
                              _closeMobile();
                              context.go(Routes.companyJobsCreate);
                            },
                            radius: 12,
                          ),
                          const SizedBox(width: 10),
                        ],

                        // User dropdown (hover in React; click here)
                        _ProfileMenu(
                          isCompany: isCompany,
                          label: _displayName(auth),
                          tag: isCompany ? "İşletme" : null,
                          items: dropdownItems,
                          onItemTap: (path) {
                            _closeMobile();
                            context.go(path);
                          },
                          onLogout: () async {
                            _closeMobile();
                            // You likely already have signOut in your controller/provider.
                            // If your signOut method is elsewhere, tell me where and I adapt.
                            await ref.read(authActionLoadingProvider.notifier).signOut();
                            if (context.mounted) context.go(Routes.home);
                          },
                        ),
                      ],
                    ] else ...[
                      // Mobile hamburger
                      IconButton(
                        onPressed: _toggleMobile,
                        icon: Icon(
                          _mobileOpen ? Icons.close : Icons.menu,
                          color: const Color(0xFF374151), // gray-700
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Mobile menu
          if (!isDesktop && _mobileOpen)
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in menuItems)
                        _MobileLink(
                          label: item.label,
                          onTap: () {
                            _closeMobile();
                            context.go(item.path);
                          },
                        ),

                      const SizedBox(height: 8),

                      if (!isLoggedIn && !isLoading)
                        _MobilePrimary(
                          label: "İşletme Girişi",
                          onTap: () {
                            _closeMobile();
                            context.go(Routes.companyAuth);
                          },
                        ),

                      const SizedBox(height: 8),

                      if (isLoading)
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        )
                      else if (!isLoggedIn) ...[
                        _MobilePrimary(
                          label: "Öğrenci Girişi",
                          onTap: () {
                            _closeMobile();
                            context.go(Routes.login);
                          },
                        ),
                        const SizedBox(height: 8),
                        _MobilePrimary(
                          label: "Kayıt Ol",
                          onTap: () {
                            _closeMobile();
                            context.go(Routes.register);
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.only(top: 12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _displayName(auth),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7C3AED),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (isCompany)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: _TagPill(text: "İşletme"),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        for (final it in dropdownItems)
                          _MobileLink(
                            label: it.label,
                            leading: it.icon,
                            onTap: () {
                              _closeMobile();
                              context.go(it.path);
                            },
                          ),

                        const SizedBox(height: 10),

                        _MobileDanger(
                          label: "Çıkış Yap",
                          onTap: () async {
                            _closeMobile();
                            await ref.read(authActionLoadingProvider.notifier).signOut();
                            if (context.mounted) context.go(Routes.home);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _displayName(AuthViewState? auth) {
    // If you have full_name in your auth models, plug it here.
    // For now: role-based placeholder.
    final t = auth?.userType;
    if (t == UserType.company) return "Company";
    if (t == UserType.admin) return "Admin";
    return "Student";
  }
}

class _NavItem {
  const _NavItem(this.label, this.path, {this.icon});
  final String label;
  final String path;
  final IconData? icon;
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827), // gray-900
          ),
        ),
      ),
    );
  }
}

class _PrimaryPillButton extends StatefulWidget {
  const _PrimaryPillButton({required this.label, required this.onTap, this.radius = 10});

  final String label;
  final VoidCallback onTap;
  final double radius;

  @override
  State<_PrimaryPillButton> createState() => _PrimaryPillButtonState();
}

class _PrimaryPillButtonState extends State<_PrimaryPillButton> {
  bool _hover = false;
  static const _purple = Color(0xFF7C3AED);
  static const _purpleHover = Color(0xFF6D28D9);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.identity()..scale(_hover ? 1.05 : 1.0),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _hover ? _purpleHover : _purple,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 6,
                  offset: Offset(0, 2),
                  color: Color(0x14000000),
                ),
              ],
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.isCompany,
    required this.label,
    required this.items,
    required this.onItemTap,
    required this.onLogout,
    this.tag,
  });

  final bool isCompany;
  final String label;
  final String? tag;
  final List<_NavItem> items;
  final ValueChanged<String> onItemTap;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 44),
      onSelected: (value) async {
        if (value == '__logout__') {
          await onLogout();
          return;
        }
        onItemTap(value);
      },
      itemBuilder: (context) => [
        for (final it in items)
          PopupMenuItem<String>(
            value: it.path,
            child: Row(
              children: [
                if (it.icon != null) ...[
                  Icon(it.icon, size: 18, color: const Color(0xFF374151)),
                  const SizedBox(width: 10),
                ],
                Text(it.label),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__logout__',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 18, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text(
                'Çıkış Yap',
                style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        children: [
          Icon(isCompany ? Icons.apartment : Icons.person, size: 18, color: const Color(0xFF111827)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            _TagPill(text: tag!),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 18, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF), // purple-100
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'İşletme',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _MobileLink extends StatelessWidget {
  const _MobileLink({required this.label, required this.onTap, this.leading});

  final String label;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 18, color: const Color(0xFF6B7280)),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobilePrimary extends StatelessWidget {
  const _MobilePrimary({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _MobileDanger extends StatelessWidget {
  const _MobileDanger({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}