// lib/src/shared/widgets/app_navbar.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
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

  // Type-safe metadata read
  String? _metaString(Map<String, dynamic>? meta, String key) {
    final v = meta?[key];
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }

  String _displayNameFromUser(User? user, String fallbackName) {
    if (user == null) return fallbackName;

    final fullName = _metaString(user.userMetadata, 'full_name');
    if (fullName != null) return fullName;

    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;

    return fallbackName;
  }

  Future<void> _logout(BuildContext context) async {
    final err = await ref.read(authActionLoadingProvider.notifier).signOut();
    _closeMobile();

    if (!context.mounted) return;

    if (err != null && err.isNotEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.signOutFailed(err))));
      return;
    }
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(appLocaleProvider);
    final authAsync = ref.watch(authViewStateProvider);
    final isLoading = authAsync.isLoading;
    final auth = authAsync.value;

    final isLoggedIn = (!isLoading) && (auth?.isAuthenticated ?? false);

    // IMPORTANT: default should be guest (not student)
    final userType = auth?.userType ?? UserType.guest;

    // Real Supabase User (from AuthViewState)
    final user = auth?.user;

    // Safe display name
    final userName = _displayNameFromUser(user, l10n.t(AppText.user));

    final isCompany = isLoggedIn && userType == UserType.company;
    final isStudent = isLoggedIn && userType == UserType.student;

    // React-like menu sets
    final studentMenu = <_NavItem>[
      _NavItem(l10n.t(AppText.navHome), Routes.home),
      _NavItem(l10n.t(AppText.navCourses), Routes.courses),
      _NavItem(l10n.t(AppText.navJobs), Routes.jobs),
      _NavItem(l10n.t(AppText.navInternships), Routes.internships),
      _NavItem('Development', Routes.development),
      _NavItem(l10n.t(AppText.navChat), Routes.chat),
    ];

    final companyMenu = <_NavItem>[
      _NavItem(l10n.t(AppText.navCompanyJobs), Routes.companyJobs),
      _NavItem(
        l10n.t(AppText.navCompanyInternships),
        Routes.companyInternships,
      ),
      _NavItem('Talent Mining', Routes.companyTalent),
      _NavItem(l10n.t(AppText.navChat), Routes.companyChat),
      _NavItem(
        l10n.t(AppText.navCompanyApplications),
        Routes.companyApplications,
      ),
      _NavItem(l10n.t(AppText.navCompanyReports), Routes.companyReports),
    ];

    final menuItems = isCompany ? companyMenu : studentMenu;

    final studentDropdown = <_NavItem>[
      _NavItem(l10n.t(AppText.navProfile), Routes.profile),
      _NavItem(l10n.t(AppText.navDashboard), Routes.dashboard),
      _NavItem('Evidence', Routes.evidence),
      _NavItem('Instant Focus Check', Routes.focusCheck),
      _NavItem('Case Analysis', Routes.caseAnalysis),
      _NavItem(l10n.t(AppText.navCareerAssistant), Routes.chat),
      _NavItem(l10n.t(AppText.navMyApplications), Routes.applications),
      _NavItem(l10n.t(AppText.navFavorites), Routes.favorites),
      _NavItem(l10n.t(AppText.navNotifications), Routes.notifications),
      _NavItem(l10n.t(AppText.navSettings), Routes.settings),
    ];

    final companyDropdown = <_NavItem>[
      _NavItem(l10n.t(AppText.navCompanyProfile), Routes.companyProfile),
      _NavItem(l10n.t(AppText.navDashboard), Routes.companyDashboard),
      _NavItem('Talent Mining', Routes.companyTalent),
      _NavItem(l10n.t(AppText.navChat), Routes.companyChat),
      _NavItem('Excuse Requests', Routes.companyExcuses),
      _NavItem('Evidence Approvals', Routes.companyEvidence),
      _NavItem(l10n.t(AppText.navPlansPricing), Routes.companyPricing),
    ];

    final dropdownItems = isCompany ? companyDropdown : studentDropdown;

    // Desktop breakpoint: keep plenty of room for nav links + actions (avoid overflow on tablets)
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1024;

    // Note: actual in-bar width is constrained below; we further compact some controls based on that width.
    final languageMenuDesktop = _LanguageMenu(
      l10n: l10n,
      currentLocale: locale,
      onSelected: (next) =>
          unawaited(ref.read(appLocaleProvider.notifier).setLocale(next)),
      compact: false,
    );
    final languageMenuMobile = _LanguageMenu(
      l10n: l10n,
      currentLocale: locale,
      onSelected: (next) =>
          unawaited(ref.read(appLocaleProvider.notifier).setLocale(next)),
      compact: true,
    );

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
      color: cs.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withAlpha(160)),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 2),
              color: cs.primary.withAlpha(14),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top bar
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final barW = constraints.maxWidth;

                        // Width-driven compaction to avoid overflow when translations are longer.
                        // We estimate "fixed" widths (logo + actions) based on current translations,
                        // and only show the wide action set if it fits comfortably.
                        final textDirection = Directionality.of(context);
                        double measure(String s, TextStyle style) {
                          final tp = TextPainter(
                            text: TextSpan(text: s, style: style),
                            maxLines: 1,
                            textDirection: textDirection,
                          )..layout();
                          return tp.size.width;
                        }

                        double pillWidth(
                          String label, {
                          required TextStyle style,
                          double? maxTextWidth,
                        }) {
                          final w = measure(label, style);
                          final tw = maxTextWidth == null
                              ? w
                              : w.clamp(0, maxTextWidth).toDouble();
                          // Matches _PrimaryPill padding (14 + 14) and keeps a tiny buffer.
                          return tw + 28 + 2;
                        }

                        // Rough widths for the logo block:
                        // icon/image (~40) + gap (10) + optional title.
                        const brandStyle = TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        );
                        final brandLabel = isCompany
                            ? l10n.t(AppText.companyPanel)
                            : l10n.t(AppText.brandName);
                        final brandTextW = measure(brandLabel, brandStyle);
                        final logoBaseW = 40 + 10;

                        // Language pill: icon(16) + gaps + label + chevron(16)
                        const langStyle = TextStyle(
                          fontWeight: FontWeight.w600,
                        );
                        final currentLang = AppLocalizations.languageFor(
                          locale,
                        );
                        final langLabelWide = currentLang.nativeName;
                        final langLabelCompact = currentLang.code.toUpperCase();
                        final langWideW =
                            16 +
                            6 +
                            measure(langLabelWide, langStyle) +
                            4 +
                            16 +
                            20;
                        final langCompactW =
                            16 +
                            6 +
                            measure(langLabelCompact, langStyle) +
                            4 +
                            16 +
                            20;

                        // Wide guest actions (3 buttons) only if they fit.
                        const pillStyle = TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        );
                        final guestButtonsW =
                            pillWidth(
                              l10n.t(AppText.companyLogin),
                              style: pillStyle,
                              maxTextWidth: 160,
                            ) +
                            10 +
                            pillWidth(
                              l10n.t(AppText.studentLogin),
                              style: pillStyle,
                              maxTextWidth: 160,
                            ) +
                            10 +
                            pillWidth(
                              l10n.t(AppText.signUp),
                              style: pillStyle,
                              maxTextWidth: 160,
                            );

                        // Compact guest actions: one menu pill.
                        final guestMenuW = pillWidth(
                          l10n.t(AppText.login),
                          style: pillStyle,
                          maxTextWidth: 140,
                        );

                        // Logged-in actions: optional "New Listing" pill + profile pill.
                        final newListingW = pillWidth(
                          l10n.t(AppText.newListing),
                          style: pillStyle,
                          maxTextWidth: 160,
                        );
                        // Profile pill: icon(18) + gaps + name + optional badge + chevron.
                        const profileStyle = TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        );
                        final profileNameW = measure(
                          userName,
                          profileStyle,
                        ).clamp(0, 160).toDouble();
                        final profileWideW =
                            18 +
                            8 +
                            profileNameW +
                            (isCompany ? (8 + 72) : 0) +
                            8 +
                            16 +
                            20;
                        final profileCompactW = 18 + 8 + 16 + 20;

                        // Leave some breathing room for the center nav links.
                        // NOTE: These gaps must match the actual Row layout below, otherwise we can
                        // incorrectly think we have room and still overflow in some locales.
                        const gapLogoToNav = 12.0;
                        const gapNavToActions = 12.0;
                        const minNavW = 260.0;

                        // When space is tight, prefer keeping the navbar stable (no overflow) over showing the brand text.
                        final minRightCushion = isLoggedIn
                            ? (langCompactW +
                                  10 +
                                  (isStudent
                                      ? (92 + 12)
                                      : 0) + // _PointsChip + gap
                                  (isCompany
                                      ? (48 + 12)
                                      : 0) + // compact new listing icon + gap
                                  profileCompactW)
                            : (langCompactW + 10 + guestMenuW);
                        final canShowBrandText =
                            barW >=
                            (logoBaseW +
                                brandTextW +
                                gapLogoToNav +
                                minNavW +
                                gapNavToActions +
                                minRightCushion);
                        final showBrandText = canShowBrandText;

                        final leftW =
                            logoBaseW + (showBrandText ? brandTextW : 0);

                        double rightWForGuest({required bool wide}) {
                          if (wide) return langWideW + 10 + guestButtonsW;
                          return langCompactW + 10 + guestMenuW;
                        }

                        double rightWForLoggedIn({required bool wide}) {
                          final langW = wide ? langWideW : langCompactW;
                          final profileW = wide
                              ? profileWideW
                              : profileCompactW;
                          final companyW = isCompany
                              ? (wide
                                    ? (newListingW + 12)
                                    : (48 + 12)) // IconButton ~48
                              : 0.0;
                          final studentW = isStudent
                              ? (92 + 12)
                              : 0.0; // _PointsChip ~92
                          return langW + 10 + studentW + companyW + profileW;
                        }

                        final showWideActions =
                            isDesktop &&
                            (isLoggedIn
                                ? (leftW +
                                          gapLogoToNav +
                                          minNavW +
                                          gapNavToActions +
                                          rightWForLoggedIn(wide: true) <=
                                      barW)
                                : (leftW +
                                          gapLogoToNav +
                                          minNavW +
                                          gapNavToActions +
                                          rightWForGuest(wide: true) <=
                                      barW));

                        final langMenu = showWideActions
                            ? languageMenuDesktop
                            : _LanguageMenu(
                                l10n: l10n,
                                currentLocale: locale,
                                onSelected: (next) => unawaited(
                                  ref
                                      .read(appLocaleProvider.notifier)
                                      .setLocale(next),
                                ),
                                compact: true,
                              );

                        return Row(
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
                                    const Icon(
                                      Icons.apartment,
                                      size: 34,
                                      color: Color(0xFF14B8A6),
                                    ),
                                    const SizedBox(width: 10),
                                    if (showBrandText)
                                      Text(
                                        l10n.t(AppText.companyPanel),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF14B8A6),
                                        ),
                                      ),
                                  ] else ...[
                                    Image.asset(
                                      'assets/logo.png',
                                      height: 40,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, error, stackTrace) =>
                                          const Icon(
                                            Icons.school,
                                            size: 34,
                                            color: Color(0xFF14B8A6),
                                          ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (showBrandText)
                                      Text(
                                        l10n.t(AppText.brandName),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF14B8A6),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Desktop menu
                            if (isDesktop) ...[
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const ClampingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        for (final item in menuItems)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
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
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              langMenu,
                              const SizedBox(width: 10),

                              // Right actions (React-like)
                              if (isLoading)
                                const SizedBox(
                                  width: 90,
                                  height: 36,
                                  child: _SkeletonPill(),
                                )
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
                                  if (showWideActions)
                                    _PrimaryPill(
                                      label: l10n.t(AppText.newListing),
                                      maxWidth: 160,
                                      rounded: 14,
                                      onTap: () {
                                        _closeMobile();
                                        context.go(Routes.companyJobsCreate);
                                      },
                                    )
                                  else
                                    IconButton(
                                      tooltip: l10n.t(AppText.newListing),
                                      onPressed: () {
                                        _closeMobile();
                                        context.go(Routes.companyJobsCreate);
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Color(0xFF14B8A6),
                                      ),
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
                                  // Use controller signOut (type-safe flow)
                                  onLogout: () => _logout(context),
                                  compact: !showWideActions,
                                ),
                              ] else ...[
                                if (showWideActions) ...[
                                  _PrimaryPill(
                                    label: l10n.t(AppText.companyLogin),
                                    maxWidth: 160,
                                    onTap: () {
                                      _closeMobile();
                                      context.go(Routes.companyAuth);
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _PrimaryPill(
                                    label: l10n.t(AppText.studentLogin),
                                    maxWidth: 160,
                                    onTap: () {
                                      _closeMobile();
                                      context.go(Routes.login);
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  TextButton.icon(
                                    onPressed: () {
                                      _closeMobile();
                                      context.go(Routes.adminLogin);
                                    },
                                    icon: const Icon(Icons.security),
                                    label: Text(l10n.t(AppText.adminPanelTitle)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF14B8A6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: cs.outlineVariant.withAlpha(
                                            180,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _PrimaryPill(
                                    label: l10n.t(AppText.signUp),
                                    maxWidth: 160,
                                    onTap: () {
                                      _closeMobile();
                                      context.go(Routes.register);
                                    },
                                  ),
                                ] else
                                  _LoginMenuPill(
                                    l10n: l10n,
                                    onStudent: () {
                                      _closeMobile();
                                      context.go(Routes.login);
                                    },
                                    onCompany: () {
                                      _closeMobile();
                                      context.go(Routes.companyAuth);
                                    },
                                    onAdmin: () {
                                      _closeMobile();
                                      context.go(Routes.adminLogin);
                                    },
                                    onSignUp: () {
                                      _closeMobile();
                                      context.go(Routes.register);
                                    },
                                  ),
                              ],
                            ],

                            // Mobile hamburger
                            if (!isDesktop)
                              IconButton(
                                tooltip: _mobileOpen
                                    ? l10n.t(AppText.close)
                                    : l10n.t(AppText.menu),
                                onPressed: () =>
                                    setState(() => _mobileOpen = !_mobileOpen),
                                icon: Icon(
                                  _mobileOpen ? Icons.close : Icons.menu,
                                ),
                              ),
                          ],
                        );
                      },
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
                          border: Border(
                            top: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: LayoutBuilder(
                          builder: (context, _) {
                            final media = MediaQuery.of(context);
                            const outerVerticalPadding = 10 + 16;
                            final topBarApproxHeight =
                                kToolbarHeight + 24; // padding + breathing room
                            final maxMenuHeight = (media.size.height -
                                    media.padding.top -
                                    media.padding.bottom -
                                    topBarApproxHeight -
                                    outerVerticalPadding)
                                .clamp(240.0, double.infinity);

                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 520),
                                child: SizedBox(
                                  height: maxMenuHeight,
                                  child: Scrollbar(
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.only(
                                        bottom: media.padding.bottom,
                                      ),
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
                                          Center(child: languageMenuMobile),
                                          const SizedBox(height: 8),

                                          if (!isLoggedIn)
                                            _MobilePrimary(
                                              label:
                                                  l10n.t(AppText.companyLogin),
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
                                                label:
                                                    l10n.t(AppText.pointsSystem),
                                                leading: const Icon(
                                                  Icons.emoji_events,
                                                  size: 18,
                                                ),
                                                onTap: () {
                                                  _closeMobile();
                                                  context.go(
                                                    Routes.pointsSystem,
                                                  );
                                                },
                                              ),

                                            if (isCompany) ...[
                                              const SizedBox(height: 6),
                                              _MobilePrimary(
                                                label:
                                                    l10n.t(AppText.newListing),
                                                onTap: () {
                                                  _closeMobile();
                                                  context.go(
                                                    Routes.companyJobsCreate,
                                                  );
                                                },
                                              ),
                                            ],

                                            const Divider(height: 22),

                                            _MobileHeader(
                                              title: userName,
                                              badge: isCompany
                                                  ? l10n.t(
                                                      AppText.companyBadge,
                                                    )
                                                  : null,
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
                                              label: l10n.t(AppText.signOut),
                                              onTap: () => _logout(context),
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 10),
                                            _MobilePrimary(
                                              label:
                                                  l10n.t(AppText.studentLogin),
                                              onTap: () {
                                                _closeMobile();
                                                context.go(Routes.login);
                                              },
                                            ),
                                            const SizedBox(height: 8),
                                            _MobilePrimary(
                                              label: l10n.t(AppText.signUp),
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
                                ),
                              ),
                            );
                          },
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
    this.maxWidth,
  });

  final String label;
  final VoidCallback onTap;
  final double rounded;
  final double? maxWidth;

  @override
  State<_PrimaryPill> createState() => _PrimaryPillState();
}

class _PrimaryPillState extends State<_PrimaryPill> {
  bool _hover = false;
  static const _purple = Color(0xFF6366F1);
  static const _purpleHover = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    final enableHover = kIsWeb;
    final text = Text(
      widget.label,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
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
                  color: Color(0x167C3AED),
                ),
              ],
            ),
            child: widget.maxWidth == null
                ? text
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.maxWidth!),
                    child: text,
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
            const Icon(Icons.emoji_events, size: 16, color: Color(0xFF14B8A6)),
            const SizedBox(width: 6),
            FutureBuilder<int>(
              future: future,
              builder: (_, snap) {
                final v = snap.data ?? 0;
                return Text(
                  '$v',
                  style: const TextStyle(
                    color: Color(0xFF14B8A6),
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
    this.compact = false,
  });

  final String userName;
  final bool isCompany;
  final List<_NavItem> items;
  final void Function(String path) onItemTap;
  final Future<void> Function() onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.t(AppText.profileMenu),
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
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logout(),
          child: Text(
            l10n.t(AppText.signOut),
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompany ? Icons.apartment : Icons.person,
            size: 18,
            color: const Color(0xFF374151),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                userName,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF374151),
                ),
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
                child: Text(
                  l10n.t(AppText.companyBadge),
                  style: const TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 18, color: Color(0xFF64748B)),
        ],
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.l10n,
    required this.currentLocale,
    required this.onSelected,
    required this.compact,
  });

  final AppLocalizations l10n;
  final Locale currentLocale;
  final ValueChanged<Locale> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final current = AppLocalizations.languageFor(currentLocale);
    return PopupMenuButton<Locale>(
      tooltip: l10n.t(AppText.language),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final language in AppLocalizations.languages)
          PopupMenuItem<Locale>(
            value: language.locale,
            child: Row(
              children: [
                if (language.code == current.code)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16, height: 16),
                const SizedBox(width: 8),
                Text(language.nativeName),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(999),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: Color(0xFF374151)),
            const SizedBox(width: 6),
            Text(
              compact ? current.code.toUpperCase() : current.nativeName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _LoginMenuPill extends StatelessWidget {
  const _LoginMenuPill({
    required this.l10n,
    required this.onStudent,
    required this.onCompany,
    required this.onAdmin,
    required this.onSignUp,
  });

  final AppLocalizations l10n;
  final VoidCallback onStudent;
  final VoidCallback onCompany;
  final VoidCallback onAdmin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LoginMenuAction>(
      tooltip: l10n.t(AppText.login),
      offset: const Offset(0, 12),
      onSelected: (action) {
        switch (action) {
          case _LoginMenuAction.student:
            onStudent();
            break;
          case _LoginMenuAction.company:
            onCompany();
            break;
          case _LoginMenuAction.admin:
            onAdmin();
            break;
          case _LoginMenuAction.signUp:
            onSignUp();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_LoginMenuAction>(
          value: _LoginMenuAction.student,
          child: Text(l10n.t(AppText.studentLogin)),
        ),
        PopupMenuItem<_LoginMenuAction>(
          value: _LoginMenuAction.company,
          child: Text(l10n.t(AppText.companyLogin)),
        ),
        PopupMenuItem<_LoginMenuAction>(
          value: _LoginMenuAction.admin,
          child: Text(l10n.t(AppText.adminPanelTitle)),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_LoginMenuAction>(
          value: _LoginMenuAction.signUp,
          child: Text(l10n.t(AppText.signUp)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 6),
              color: Color(0x167C3AED),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.login, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              l10n.t(AppText.login),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 16, color: Color(0xDDFFFFFF)),
          ],
        ),
      ),
    );
  }
}

enum _LoginMenuAction { student, company, admin, signUp }

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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF14B8A6),
            ),
          ),
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
                style: const TextStyle(
                  color: Color(0xFF14B8A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
        color: const Color(0xFFE2E8F0),
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
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
