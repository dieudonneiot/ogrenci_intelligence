import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/routing/routes.dart';

class AppFooter extends StatefulWidget {
  const AppFooter({super.key});

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _subscribe() {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.footerSubscribeInvalid))),
      );
      return;
    }

    _emailCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t(AppText.footerSubscribeSuccess))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final year = DateTime.now().year;

    final fg = cs.onPrimary;
    final fgMuted = fg.withAlpha(210);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final isNarrow = c.maxWidth < 820;
                      final sectionWidth = isNarrow ? c.maxWidth : 220.0;

                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          SizedBox(
                            width: sectionWidth,
                            child: _FooterSection(
                              title: l10n.t(AppText.footerPlatformTitle),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.t(AppText.footerPlatformDesc),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: fgMuted,
                                      height: 1.35,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    children: const [
                                      _SocialIcon(
                                        icon: Icons.facebook,
                                        tooltip: 'Facebook',
                                      ),
                                      _SocialIcon(
                                        icon: Icons.alternate_email,
                                        tooltip: 'X / Twitter',
                                      ),
                                      _SocialIcon(
                                        icon: Icons.camera_alt,
                                        tooltip: 'Instagram',
                                      ),
                                      _SocialIcon(
                                        icon: Icons.business_center,
                                        tooltip: 'LinkedIn',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: sectionWidth,
                            child: _FooterSection(
                              title: l10n.t(AppText.footerQuickLinks),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FooterLink(
                                    label: l10n.t(AppText.navCourses),
                                    route: Routes.courses,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(AppText.navJobs),
                                    route: Routes.jobs,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(
                                      AppText.linkInternshipListings,
                                    ),
                                    route: Routes.internships,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(AppText.linkLeaderboard),
                                    route: Routes.leaderboard,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: sectionWidth,
                            child: _FooterSection(
                              title: l10n.t(AppText.footerMore),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FooterLink(
                                    label: l10n.t(AppText.linkHowItWorks),
                                    route: Routes.howItWorks,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(AppText.linkAbout),
                                    route: Routes.about,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(AppText.linkContact),
                                    route: Routes.contact,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(AppText.linkPrivacy),
                                    route: Routes.privacy,
                                  ),
                                  _FooterLink(
                                    label: l10n.t(AppText.linkTerms),
                                    route: Routes.terms,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: isNarrow ? c.maxWidth : 280,
                            child: _FooterSection(
                              title: l10n.t(AppText.footerNewsletter),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.t(AppText.footerNewsletterDesc),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: fgMuted,
                                      height: 1.35,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _emailCtrl,
                                          style: TextStyle(color: fg),
                                          decoration: InputDecoration(
                                            hintText: l10n.t(
                                              AppText.footerEmailHint,
                                            ),
                                            hintStyle: TextStyle(
                                              color: fg.withAlpha(170),
                                            ),
                                            filled: true,
                                            fillColor: fg.withAlpha(26),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: _subscribe,
                                        icon: Icon(Icons.send, color: fg),
                                        style: IconButton.styleFrom(
                                          backgroundColor: fg.withAlpha(26),
                                          padding: const EdgeInsets.all(10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Divider(color: fg.withAlpha(40)),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      l10n.footerCopyright('$year'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fgMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onPrimary;
    return InkWell(
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: fg.withAlpha(210),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = cs.onPrimary;
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.linkComingSoon(tooltip))));
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: fg.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: fg, size: 16),
        ),
      ),
    );
  }
}
