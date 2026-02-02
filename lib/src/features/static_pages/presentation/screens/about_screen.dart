import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _values = <_ValueCard>[
    _ValueCard(
      icon: Icons.flag_outlined,
      title: 'Misyonumuz',
      description:
          'Öğrencilerin kariyerlerini şekillendirmelerine yardımcı olmak, onları sektörle buluşturmak ve potansiyellerini keşfetmelerini sağlamak.',
    ),
    _ValueCard(
      icon: Icons.favorite_border,
      title: 'Değerlerimiz',
      description:
          'Eşitlik, fırsat yaratma, sürekli öğrenme ve gelişim. Her öğrencinin başarılı olabileceğine inanıyoruz.',
    ),
    _ValueCard(
      icon: Icons.bolt_outlined,
      title: 'Vizyonumuz',
      description:
          "Türkiye'nin en kapsamlı öğrenci kariyer platformu olmak ve her yıl binlerce öğrencinin hayallerine ulaşmasına katkı sağlamak.",
    ),
  ];

  static const _stats = <_StatCard>[
    _StatCard(number: '10.000+', label: 'Aktif Öğrenci'),
    _StatCard(number: '500+', label: 'Partner Şirket'),
    _StatCard(number: '1.000+', label: 'Staj İmkanı'),
    _StatCard(number: '50+', label: 'Online Kurs'),
  ];

  static const _teamRoles = <String>['Ürün', 'Pazarlama', 'Topluluk', 'Teknoloji'];

  @override
  Widget build(BuildContext context) {
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
                _StoryCard(stats: _stats),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Değerlerimiz',
                  subtitle: 'Bizi ileri taşıyan temel prensipler.',
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final crossAxis = c.maxWidth < 820 ? 1 : 3;
                    final width = (c.maxWidth - (crossAxis - 1) * 16) / crossAxis;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final value in _values)
                          SizedBox(width: width, child: _ValueCardView(card: value)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _TeamSection(roles: _teamRoles),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: _GlowCircle(color: Colors.white.withValues(alpha: 0.12), size: 140),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: _GlowCircle(color: Colors.white.withValues(alpha: 0.10), size: 120),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Hakkımızda',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
              SizedBox(height: 10),
              Text(
                'Öğrenci Intelligence, öğrenciler ve işverenler arasında köprü kurarak kariyer yolculuğunu hızlandıran bir ekosistem sunar.',
                style: TextStyle(color: Color(0xFFE0E7FF), height: 1.4),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8))],
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hikayemiz', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        SizedBox(height: 12),
        Text(
          '2023 yılında, üniversite öğrencilerinin yaşadığı staj bulma zorluğunu ve mezuniyet sonrası iş arama sürecindeki belirsizlikleri gözlemleyerek yola çıktık.',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
        ),
        SizedBox(height: 10),
        Text(
          'Amacımız yalnızca iş ve staj bulmayı kolaylaştırmak değil; kurslar, mentorluk ve puan sistemiyle öğrencilerin sürekli gelişimini desteklemek.',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
        ),
        SizedBox(height: 10),
        Text(
          'Bugün binlerce öğrenci platformumuz üzerinden kariyerlerine yön veriyor. Her başarı hikayesi bizim için yeni bir motivasyon.',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
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
        gradient: const LinearGradient(colors: [Color(0xFFEDE9FE), Color(0xFFE0E7FF)]),
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
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _ValueCard {
  const _ValueCard({required this.icon, required this.title, required this.description});

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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
            child: Icon(card.icon, color: const Color(0xFF6D28D9), size: 30),
          ),
          const SizedBox(height: 12),
          Text(card.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(card.description, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
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
        Text(card.number, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6D28D9))),
        const SizedBox(height: 4),
        Text(card.label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF374151))),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Ekibimiz', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text(
            'Öğrencilerin kariyerlerine değer katmak için tutkuyla çalışan, deneyimli ve dinamik bir ekibiz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
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
                        const CircleAvatar(radius: 38, backgroundColor: Color(0xFFC4B5FD)),
                        const SizedBox(height: 8),
                        const Text('Takım Üyesi', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text(roles[index], style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Text('Neden Biz?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
                    child: const _WhyItem(
                      icon: Icons.people_outline,
                      title: 'Geniş Ağ',
                      description: "500'den fazla partner şirket ve binlerce aktif öğrenci ile güçlü bir kariyer ağı.",
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _WhyItem(
                      icon: Icons.card_giftcard,
                      title: 'Ödül Sistemi',
                      description: 'Aktiviteleriniz karşılığında puan kazanın, bu puanları gerçek ödüllerle değiştirin.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _WhyItem(
                      icon: Icons.trending_up,
                      title: 'Kariyer Gelişimi',
                      description: 'Online kurslar, mentorluk programları ve kariyer etkinlikleri ile gelişiminizi destekliyoruz.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _WhyItem(
                      icon: Icons.favorite_outline,
                      title: 'Öğrenci Dostu',
                      description: 'Tamamen ücretsiz platform, öğrenci ihtiyaçlarına göre tasarlanmış arayüz ve özellikler.',
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
  const _WhyItem({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6D28D9), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
