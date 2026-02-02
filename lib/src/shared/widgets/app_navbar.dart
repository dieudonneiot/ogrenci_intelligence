// lib/src/shared/widgets/app_navbar.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/routing/routes.dart';
import '../../core/supabase/supabase_service.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

class AppNavbar extends ConsumerStatefulWidget {
  const AppNavbar({super.key});

  @override
  ConsumerState<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends ConsumerState<AppNavbar> {
  bool _mobileOpen = false;

  // Points cache (student only)
  Future<int>? _pointsFuture;
  String? _pointsUserId;

  // ✅ Type-safe metadata read
  String? _metaString(Map<String, dynamic>? meta, String key) {
    final v = meta?[key];
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }

  String _displayNameFromUser(User? user) {
    if (user == null) return 'Kullanıcı';

    final fullName = _metaString(user.userMetadata, 'full_name');
    if (fullName != null) return fullName;

    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Kullanıcı';
  }

  Future<void> _logout(BuildContext context) async {
    final err = await ref.read(authActionLoadingProvider.notifier).signOut();
    _closeMobile();

    if (!context.mounted) return;

    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılamadı: $err')),
      );
      return;
    }
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);
    final isLoading = authAsync.isLoading;
    final auth = authAsync.value;

    final isLoggedIn = (!isLoading) && (auth?.isAuthenticated ?? false);

    // ✅ IMPORTANT: default should be guest (not student)
    final userType = auth?.userType ?? UserType.guest;

    // ✅ Real Supabase User (from AuthViewState)
    final user = auth?.user;

    // ✅ Safe display name
    final userName = _displayNameFromUser(user);

    final isCompany = isLoggedIn && userType == UserType.company;
    final isStudent = isLoggedIn && userType == UserType.student;

    // React-like menu sets
    final studentMenu = const <_NavItem>[
      _NavItem('Anasayfa', Routes.home),
      _NavItem('Kurslar', Routes.courses),
      _NavItem('İş İlanları', Routes.jobs),
      _NavItem('Stajlar', Routes.internships),
    ];

    final companyMenu = const <_NavItem>[
      _NavItem('İlanlarım', Routes.companyJobs),
      _NavItem('Staj Yönetimi', Routes.companyInternships),
      _NavItem('Başvurular', Routes.companyApplications),
      _NavItem('Raporlar', Routes.companyReports),
    ];

    final menuItems = isCompany ? companyMenu : studentMenu;

    final studentDropdown = const <_NavItem>[
      _NavItem('Profilim', Routes.profile),
      _NavItem('Dashboard', Routes.dashboard),
      _NavItem('Başvurularım', Routes.applications),
      _NavItem('Favorilerim', Routes.favorites),
      _NavItem('Bildirimler', Routes.notifications),
      _NavItem('Ayarlar', Routes.settings),
    ];

    final companyDropdown = const <_NavItem>[
      _NavItem('Şirket Profili', Routes.companyProfile),
      _NavItem('Dashboard', Routes.companyDashboard),
      _NavItem('Paketler ve Fiyatlar', Routes.companyPricing),
    ];

    final dropdownItems = isCompany ? companyDropdown : studentDropdown;

    // Desktop breakpoint similar to React md+
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 768;

    // Student points chip: prepare/cached future
    if (isStudent) {
      final uid = user?.id;
      if (uid != null && uid.isNotEmpty && uid != _pointsUserId) {
        _pointsUserId = uid;
        _pointsFuture = _fetchUserTotalPoints(uid);
      }
    } else {
      _pointsUserId = null;
      _pointsFuture = null;
    }

    return Material(
      elevation: 0,
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 2),
              color: Color(0x14000000),
            )
          ],
        ),
        child: Column(
          children: [
            // Top bar
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        // Logo + Title (React: logo changes for company)
                        InkWell(
                          onTap: () {
                            _closeMobile();
                            if (isCompany) {
                              context.go(Routes.companyDashboard);
                            } else {
                              context.go(Routes.home);
                            }
                          },
                          child: Row(
                            children: [
                              if (isCompany) ...[
                                const Icon(Icons.apartment, size: 34, color: Color(0xFF6D28D9)),
                                const SizedBox(width: 10),
                                if (isDesktop)
                                  const Text(
                                    'İşletme Paneli',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                              ] else ...[
                                Image.asset(
                                  'assets/logo.png',
                                  height: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, error, stackTrace) => const Icon(
                                    Icons.school,
                                    size: 34,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (isDesktop)
                                  const Text(
                                    'Öğrenci İntelligence',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                              ]
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Desktop menu
                        if (isDesktop) ...[
                          Row(
                            children: [
                              for (final item in menuItems)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: _NavTextLink(
                                    label: item.label,
                                    onTap: () {
                                      _closeMobile();
                                      context.go(item.path);
                                    },
                                  ),
                                ),
                            ],
                          ),

                          const Spacer(),

                          // Right actions (React-like)
                          if (!isLoggedIn) ...[
                            _PrimaryPill(
                              label: 'İşletme Girişi',
                              onTap: () {
                                _closeMobile();
                                context.go(Routes.companyAuth);
                              },
                            ),
                            const SizedBox(width: 10),
                          ],

                          if (isLoading)
                            const SizedBox(width: 90, height: 36, child: _SkeletonPill())
                          else if (isLoggedIn) ...[
                            if (isStudent) ...[
                              _PointsChip(
                                future: _pointsFuture,
                                onTap: () {
                                  _closeMobile();
                                  context.go(Routes.pointsSystem);
                                },
                              ),
                              const SizedBox(width: 12),
                            ],

                            if (isCompany) ...[
                              _PrimaryPill(
                                label: 'Yeni İlan',
                                rounded: 14,
                                onTap: () {
                                  _closeMobile();
                                  context.go(Routes.companyJobsCreate);
                                },
                              ),
                              const SizedBox(width: 12),
                            ],

                            _ProfileDropdown(
                              userName: userName,
                              isCompany: isCompany,
                              items: dropdownItems,
                              onItemTap: (path) {
                                _closeMobile();
                                context.go(path);
                              },
                              // ✅ Use controller signOut (type-safe flow)
                              onLogout: () => _logout(context),
                            ),
                          ] else ...[
                            _PrimaryPill(
                              label: 'Öğrenci Girişi',
                              onTap: () {
                                _closeMobile();
                                context.go(Routes.login);
                              },
                            ),
                            const SizedBox(width: 10),
                            _PrimaryPill(
                              label: 'Kayıt Ol',
                              onTap: () {
                                _closeMobile();
                                context.go(Routes.register);
                              },
                            ),
                          ],
                        ],

                        // Mobile hamburger
                        if (!isDesktop)
                          IconButton(
                            tooltip: _mobileOpen ? 'Kapat' : 'Menü',
                            onPressed: () => setState(() => _mobileOpen = !_mobileOpen),
                            icon: Icon(_mobileOpen ? Icons.close : Icons.menu),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Mobile menu (React slideDown)
            if (!isDesktop)
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _mobileOpen
                    ? Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              children: [
                                for (final item in menuItems)
                                  _MobileTile(
                                    label: item.label,
                                    onTap: () {
                                      _closeMobile();
                                      context.go(item.path);
                                    },
                                  ),

                                const SizedBox(height: 8),

                                if (!isLoggedIn)
                                  _MobilePrimary(
                                    label: 'İşletme Girişi',
                                    onTap: () {
                                      _closeMobile();
                                      context.go(Routes.companyAuth);
                                    },
                                  ),

                                if (isLoading) ...[
                                  const SizedBox(height: 12),
                                  const _SkeletonBlock(),
                                ] else if (isLoggedIn) ...[
                                  const SizedBox(height: 10),

                                  if (isStudent)
                                    _MobileTile(
                                      label: 'Puan Sistemi',
                                      leading: const Icon(Icons.emoji_events, size: 18),
                                      onTap: () {
                                        _closeMobile();
                                        context.go(Routes.pointsSystem);
                                      },
                                    ),

                                  if (isCompany) ...[
                                    const SizedBox(height: 6),
                                    _MobilePrimary(
                                      label: 'Yeni İlan',
                                      onTap: () {
                                        _closeMobile();
                                        context.go(Routes.companyJobsCreate);
                                      },
                                    ),
                                  ],

                                  const Divider(height: 22),

                                  _MobileHeader(
                                    title: userName,
                                    badge: isCompany ? 'İşletme' : null,
                                  ),

                                  for (final it in dropdownItems)
                                    _MobileTile(
                                      label: it.label,
                                      onTap: () {
                                        _closeMobile();
                                        context.go(it.path);
                                      },
                                    ),

                                  const SizedBox(height: 8),
                                  _MobileDanger(
                                    label: 'Çıkış Yap',
                                    onTap: () => _logout(context),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 10),
                                  _MobilePrimary(
                                    label: 'Öğrenci Girişi',
                                    onTap: () {
                                      _closeMobile();
                                      context.go(Routes.login);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _MobilePrimary(
                                    label: 'Kayıt Ol',
                                    onTap: () {
                                      _closeMobile();
                                      context.go(Routes.register);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  void _closeMobile() {
    if (_mobileOpen) setState(() => _mobileOpen = false);
  }

  Future<int> _fetchUserTotalPoints(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('total_points')
          .eq('id', userId)
          .single();

      final v = data['total_points'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }
}

class _NavItem {
  const _NavItem(this.label, this.path);
  final String label;
  final String path;
}

class _NavTextLink extends StatelessWidget {
  const _NavTextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPill extends StatefulWidget {
  const _PrimaryPill({
    required this.label,
    required this.onTap,
    this.rounded = 10,
  });

  final String label;
  final VoidCallback onTap;
  final double rounded;

  @override
  State<_PrimaryPill> createState() => _PrimaryPillState();
}

class _PrimaryPillState extends State<_PrimaryPill> {
  bool _hover = false;
  static const _purple = Color(0xFF7C3AED);
  static const _purpleHover = Color(0xFF6D28D9);

  @override
  Widget build(BuildContext context) {
    final enableHover = kIsWeb;
    return MouseRegion(
      onEnter: enableHover ? (_) => setState(() => _hover = true) : null,
      onExit: enableHover ? (_) => setState(() => _hover = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hover ? 1.05 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.rounded),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _hover ? _purpleHover : _purple,
              borderRadius: BorderRadius.circular(widget.rounded),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  offset: Offset(0, 6),
                  color: Color(0x14000000),
                )
              ],
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  const _PointsChip({required this.future, required this.onTap});
  final Future<int>? future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, size: 16, color: Color(0xFF6D28D9)),
            const SizedBox(width: 6),
            FutureBuilder<int>(
              future: future,
              builder: (_, snap) {
                final v = snap.data ?? 0;
                return Text(
                  '$v',
                  style: const TextStyle(
                    color: Color(0xFF6D28D9),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  const _ProfileDropdown({
    required this.userName,
    required this.isCompany,
    required this.items,
    required this.onItemTap,
    required this.onLogout,
  });

  final String userName;
  final bool isCompany;
  final List<_NavItem> items;
  final void Function(String path) onItemTap;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Profil Menüsü',
      offset: const Offset(0, 12),
      onSelected: (selected) async {
        if (selected.isLogout) {
          await onLogout();
        } else {
          onItemTap(selected.path!);
        }
      },
      itemBuilder: (context) => [
        for (final it in items)
          PopupMenuItem<_MenuAction>(
            value: _MenuAction.nav(it.path),
            child: Text(it.label),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.logout(),
          child: Text(
            'Çıkış Yap',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
      child: Row(
        children: [
          Icon(isCompany ? Icons.apartment : Icons.person, size: 18, color: const Color(0xFF374151)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              userName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
          if (isCompany) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'İşletme',
                style: TextStyle(color: Color(0xFF6D28D9), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 18, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction._({this.path, required this.isLogout});

  const _MenuAction.nav(String path) : this._(path: path, isLogout: false);
  const _MenuAction.logout() : this._(isLogout: true);

  final String? path;
  final bool isLogout;
}

// --------------------
// Mobile widgets
// --------------------

class _MobileTile extends StatelessWidget {
  const _MobileTile({required this.label, required this.onTap, this.leading});
  final String label;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
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
    return _PrimaryPill(label: label, onTap: onTap, rounded: 14);
  }
}

class _MobileDanger extends StatelessWidget {
  const _MobileDanger({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.title, this.badge});
  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6D28D9))),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(color: Color(0xFF6D28D9), fontSize: 11, fontWeight: FontWeight.w800),
              ),
            )
          ],
        ],
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
