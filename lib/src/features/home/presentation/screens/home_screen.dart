import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../widgets/how_it_works_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Tailwind-like palette (close to your React UI)
  static const _bgTop = Color(0xFFFFFFFF);
  static const _bgBottom = Color(0xFFFAF5FF); // purple-50
  static const _purple700 = Color(0xFF7E22CE);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authAsync = ref.watch(authViewStateProvider);

    final isLoading = authAsync.isLoading;
    final auth = authAsync.value;
    final isLoggedIn = (!isLoading) && (auth?.isAuthenticated ?? false);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(
                    isLoggedIn: isLoggedIn,
                    isLoading: isLoading,
                    onRegister: () => context.go(Routes.register),
                    onLogin: () => context.go(Routes.login),
                    onProfile: () => context.go(Routes.profile),
                    onLogout: () async {
                      await SupabaseService.client.auth.signOut();
                      if (context.mounted) context.go(Routes.home);
                    },
                  ),

                  const SizedBox(height: 36),

                  _SectionGrid(
                    title: null,
                    cards: [
                      _InfoCard(
                        icon: Icons.school_outlined,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeCard1Title),
                        description: l10n.t(AppText.homeCard1Desc),
                      ),
                      _InfoCard(
                        icon: Icons.work_outline,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeCard2Title),
                        description: l10n.t(AppText.homeCard2Desc),
                      ),
                      _InfoCard(
                        icon: Icons.assignment_outlined,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeCard3Title),
                        description: l10n.t(AppText.homeCard3Desc),
                      ),
                    ],
                  ),

                  const SizedBox(height: 56),

                  _SectionGrid(
                    title: l10n.t(AppText.homeStudentBenefitsTitle),
                    cards: [
                      _InfoCard(
                        icon: Icons.track_changes_outlined,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeStudentCard1Title),
                        description: l10n.t(AppText.homeStudentCard1Desc),
                      ),
                      _InfoCard(
                        icon: Icons.star_outline,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeStudentCard2Title),
                        description: l10n.t(AppText.homeStudentCard2Desc),
                      ),
                      _InfoCard(
                        icon: Icons.bar_chart_outlined,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeStudentCard3Title),
                        description: l10n.t(AppText.homeStudentCard3Desc),
                      ),
                    ],
                  ),

                  const SizedBox(height: 56),

                  _SectionGrid(
                    title: l10n.t(AppText.homeCompanyBenefitsTitle),
                    cards: [
                      _InfoCard(
                        icon: Icons.people_outline,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeCompanyCard1Title),
                        description: l10n.t(AppText.homeCompanyCard1Desc),
                      ),
                      _InfoCard(
                        icon: Icons.handshake_outlined,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeCompanyCard2Title),
                        description: l10n.t(AppText.homeCompanyCard2Desc),
                      ),
                      _InfoCard(
                        icon: Icons.query_stats_outlined,
                        iconColor: _purple700,
                        title: l10n.t(AppText.homeCompanyCard3Title),
                        description: l10n.t(AppText.homeCompanyCard3Desc),
                      ),
                    ],
                  ),

                  const SizedBox(height: 56),

                  // Keep it here, from widgets/how_it_works_section.dart
                  const HowItWorksSection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.isLoggedIn,
    required this.isLoading,
    required this.onRegister,
    required this.onLogin,
    required this.onProfile,
    required this.onLogout,
  });

  final bool isLoggedIn;
  final bool isLoading;
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  static const _purple700 = Color(0xFF7E22CE);
  static const _indigo700 = Color(0xFF4338CA);
  static const _blue800 = Color(0xFF1E40AF);
  static const _yellow400 = Color(0xFFFACC15);
  static const _green400 = Color(0xFF4ADE80);
  static const _red400 = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.15,
        );

    final subtitleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFFC7D2FE), // indigo-200 vibe
          height: 1.5,
        );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 40), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_purple700, _indigo700, _blue800],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(0, 10),
              color: Color(0x26000000),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          child: Column(
            children: [
              Text(
                l10n.t(AppText.homeHeroTitle),
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  l10n.t(AppText.homeHeroSubtitle),
                  textAlign: TextAlign.center,
                  style: subtitleStyle,
                ),
              ),
              const SizedBox(height: 22),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (!isLoggedIn) ...[
                      _FilledCta(
                        label: l10n.t(AppText.signUp),
                        color: _yellow400,
                        textColor: Color(0xFF111827),
                        onTap: onRegister,
                      ),
                      _FilledCta(
                        label: l10n.t(AppText.login),
                        color: _yellow400,
                        textColor: Color(0xFF111827),
                        onTap: onLogin,
                      ),
                    ] else ...[
                      _FilledCta(
                        label: l10n.t(AppText.profile),
                        color: _green400,
                        textColor: Color(0xFF111827),
                        icon: Icons.person_outline,
                        onTap: onProfile,
                      ),
                      _FilledCta(
                        label: l10n.t(AppText.signOut),
                        color: _red400,
                        textColor: Colors.white,
                        icon: Icons.logout_outlined,
                        onTapAsync: onLogout,
                      ),
                    ]
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilledCta extends StatefulWidget {
  const _FilledCta({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
    this.onTap,
    this.onTapAsync,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final VoidCallback? onTap;
  final Future<void> Function()? onTapAsync;

  @override
  State<_FilledCta> createState() => _FilledCtaState();
}

class _FilledCtaState extends State<_FilledCta> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final onPressed = (widget.onTapAsync != null)
        ? () async {
            if (_busy) return;
            setState(() => _busy = true);
            try {
              await widget.onTapAsync!.call();
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }
        : widget.onTap;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: widget.textColor,
        elevation: 10,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            _busy ? '...' : widget.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.title,
    required this.cards,
  });

  final String? title;
  final List<_InfoCard> cards;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF3B0764), // deep purple
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, textAlign: TextAlign.center, style: headerStyle),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final gap = 18.0;
            final minItem = 280.0;

            final count = (w / (minItem + gap)).floor().clamp(1, 3);
            final itemW = (w - gap * (count - 1)) / count;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards) SizedBox(width: itemW, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF5B21B6),
        );

    final descStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF4B5563),
          height: 1.45,
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Color(0x1A000000),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 46, color: iconColor),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: titleStyle),
          const SizedBox(height: 10),
          Text(description, textAlign: TextAlign.center, style: descStyle),
        ],
      ),
    );
  }
}
