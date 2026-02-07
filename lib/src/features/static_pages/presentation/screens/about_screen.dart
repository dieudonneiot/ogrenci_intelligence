import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final values = <_ValueCard>[
      _ValueCard(
        icon: Icons.flag_outlined,
        title: l10n.t(AppText.aboutValueMissionTitle),
        description: l10n.t(AppText.aboutValueMissionDesc),
      ),
      _ValueCard(
        icon: Icons.favorite_border,
        title: l10n.t(AppText.aboutValueValuesTitle),
        description: l10n.t(AppText.aboutValueValuesDesc),
      ),
      _ValueCard(
        icon: Icons.bolt_outlined,
        title: l10n.t(AppText.aboutValueVisionTitle),
        description: l10n.t(AppText.aboutValueVisionDesc),
      ),
    ];

    final stats = <_StatCard>[
      _StatCard(
        number: '10.000+',
        label: l10n.t(AppText.aboutStatActiveStudents),
      ),
      _StatCard(
        number: '500+',
        label: l10n.t(AppText.aboutStatPartnerCompanies),
      ),
      _StatCard(
        number: '1.000+',
        label: l10n.t(AppText.aboutStatInternshipOpportunities),
      ),
      _StatCard(number: '50+', label: l10n.t(AppText.aboutStatOnlineCourses)),
    ];

    final teamRoles = <String>[
      l10n.t(AppText.aboutRoleProduct),
      l10n.t(AppText.aboutRoleMarketing),
      l10n.t(AppText.aboutRoleCommunity),
      l10n.t(AppText.aboutRoleTechnology),
    ];

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                const SizedBox(height: 24),
                _StoryCard(stats: stats),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: l10n.t(AppText.aboutValuesSectionTitle),
                  subtitle: l10n.t(AppText.aboutValuesSectionSubtitle),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final crossAxis = c.maxWidth < 820 ? 1 : 3;
                    final width =
                        (c.maxWidth - (crossAxis - 1) * 16) / crossAxis;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final value in values)
                          SizedBox(
                            width: width,
                            child: _ValueCardView(card: value),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _TeamSection(roles: teamRoles),
                const SizedBox(height: 24),
                const _WhyUsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF6366F1), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: _GlowCircle(
              color: Colors.white.withValues(alpha: 0.12),
              size: 140,
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: _GlowCircle(
              color: Colors.white.withValues(alpha: 0.10),
              size: 120,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t(AppText.aboutHeroTitle),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t(AppText.aboutHeroSubtitle),
                style: const TextStyle(color: Color(0xFFE0E7FF), height: 1.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.stats});

  final List<_StatCard> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 900;
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              SizedBox(
                width: isNarrow ? c.maxWidth : c.maxWidth * 0.6,
                child: const _StoryText(),
              ),
              SizedBox(
                width: isNarrow ? c.maxWidth : c.maxWidth * 0.35,
                child: _StatsPanel(stats: stats),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryText extends StatelessWidget {
  const _StoryText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t(AppText.aboutStoryTitle),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.t(AppText.aboutStoryP1),
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.t(AppText.aboutStoryP2),
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.t(AppText.aboutStoryP3),
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final List<_StatCard> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final stat in stats)
            SizedBox(width: 120, child: _StatCardView(card: stat)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
      ],
    );
  }
}

class _ValueCard {
  const _ValueCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _ValueCardView extends StatelessWidget {
  const _ValueCardView({required this.card});

  final _ValueCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(card.icon, color: const Color(0xFF14B8A6), size: 30),
          ),
          const SizedBox(height: 12),
          Text(card.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            card.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatCard {
  const _StatCard({required this.number, required this.label});

  final String number;
  final String label;
}

class _StatCardView extends StatelessWidget {
  const _StatCardView({required this.card});

  final _StatCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          card.number,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF14B8A6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          card.label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF374151)),
        ),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            l10n.t(AppText.aboutTeamTitle),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t(AppText.aboutTeamSubtitle),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final crossAxis = c.maxWidth < 680 ? 2 : 4;
              final width = (c.maxWidth - (crossAxis - 1) * 16) / crossAxis;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 38,
                          backgroundColor: Color(0xFFC4B5FD),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t(AppText.aboutTeamMember),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          roles[index],
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WhyUsSection extends StatelessWidget {
  const _WhyUsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            l10n.t(AppText.aboutWhyTitle),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 820;
              final width = isNarrow ? c.maxWidth : (c.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _WhyItem(
                      icon: Icons.people_outline,
                      title: l10n.t(AppText.aboutWhyNetworkTitle),
                      description: l10n.t(AppText.aboutWhyNetworkDesc),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _WhyItem(
                      icon: Icons.card_giftcard,
                      title: l10n.t(AppText.aboutWhyRewardsTitle),
                      description: l10n.t(AppText.aboutWhyRewardsDesc),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _WhyItem(
                      icon: Icons.trending_up,
                      title: l10n.t(AppText.aboutWhyCareerTitle),
                      description: l10n.t(AppText.aboutWhyCareerDesc),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _WhyItem(
                      icon: Icons.favorite_outline,
                      title: l10n.t(AppText.aboutWhyStudentFriendlyTitle),
                      description: l10n.t(AppText.aboutWhyStudentFriendlyDesc),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WhyItem extends StatelessWidget {
  const _WhyItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF14B8A6), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
