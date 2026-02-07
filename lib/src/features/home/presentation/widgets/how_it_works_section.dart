import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class HowItWorksSection extends ConsumerWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final authAsync = ref.watch(authViewStateProvider);
    final isLoading = authAsync.isLoading;
    final isLoggedIn =
        (!isLoading) && (authAsync.value?.isAuthenticated ?? false);

    final w = MediaQuery.of(context).size.width;

    // Breakpoints proches du React: md=2 cols, lg=4 cols
    final columns = w >= 1024 ? 4 : (w >= 768 ? 2 : 1);
    final showArrows = columns >= 4;

    final steps = <_HowStep>[
      _HowStep(
        index: 1,
        title: l10n.t(AppText.howItWorksStep1Title),
        description: l10n.t(AppText.howItWorksStep1Desc),
        icon: Icons.menu_book_outlined,
        iconColor: Color(0xFF6366F1), // indigo-600
        bgColor: Color(0xFFEFF6FF), // indigo-50 vibe
        borderColor: Color(0xFFC7D2FE), // indigo-200
      ),
      _HowStep(
        index: 2,
        title: l10n.t(AppText.howItWorksStep2Title),
        description: l10n.t(AppText.howItWorksStep2Desc),
        icon: Icons.business_center_outlined,
        iconColor: Color(0xFF6366F1), // purple-600
        bgColor: Color(0xFFF3E8FF), // purple-50
        borderColor: Color(0xFFD8B4FE), // purple-200
      ),
      _HowStep(
        index: 3,
        title: l10n.t(AppText.howItWorksStep3Title),
        description: l10n.t(AppText.howItWorksStep3Desc),
        icon: Icons.groups_outlined,
        iconColor: Color(0xFF16A34A), // green-600
        bgColor: Color(0xFFECFDF5), // green-50
        borderColor: Color(0xFFBBF7D0), // green-200
      ),
      _HowStep(
        index: 4,
        title: l10n.t(AppText.howItWorksStep4Title),
        description: l10n.t(AppText.howItWorksStep4Desc),
        icon: Icons.emoji_events_outlined,
        iconColor: Color(0xFFCA8A04), // yellow-600
        bgColor: Color(0xFFFFFBEB), // yellow-50
        borderColor: Color(0xFFFDE68A), // yellow-200
      ),
    ];

    return Container(
      width: double.infinity,
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              // Title
              Text(
                l10n.t(AppText.howItWorksTitle),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  l10n.t(AppText.howItWorksSubtitle),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Grid
              LayoutBuilder(
                builder: (context, c) {
                  final gap = 16.0;
                  final totalW = c.maxWidth;
                  final itemW = (columns == 1)
                      ? totalW
                      : (totalW - gap * (columns - 1)) / columns;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        SizedBox(
                          width: itemW,
                          child: _HowStepCard(
                            step: steps[i],
                            showArrow: showArrows && i < steps.length - 1,
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 34),

              // CTA
              _CtaButton(
                label: isLoggedIn
                    ? l10n.t(AppText.howItWorksCtaDashboard)
                    : l10n.t(AppText.howItWorksCtaStart),
                onTap: () =>
                    context.go(isLoggedIn ? Routes.dashboard : Routes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowStep {
  const _HowStep({
    required this.index,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  final int index;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
}

class _HowStepCard extends StatefulWidget {
  const _HowStepCard({required this.step, required this.showArrow});

  final _HowStep step;
  final bool showArrow;

  @override
  State<_HowStepCard> createState() => _HowStepCardState();
}

class _HowStepCardState extends State<_HowStepCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hover ? -4.0 : 0.0, 0.0, 1.0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: widget.step.bgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.step.borderColor, width: 2),
              boxShadow: _hover
                  ? const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        color: Color(0x1A000000),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.step.icon, size: 40, color: widget.step.iconColor),
                const SizedBox(height: 12),
                Text(
                  widget.step.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.step.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5563),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          // Step number (top-right)
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.step.index}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Arrow (only large screens / not last)
          if (widget.showArrow)
            const Positioned(
              right: -14,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.arrow_forward,
                  size: 22,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  const _CtaButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hover = false;
  static const _purple = Color(0xFF6366F1);
  static const _purpleHover = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hover ? 1.05 : 1.0,
        child: ElevatedButton(
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _hover ? _purpleHover : _purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
