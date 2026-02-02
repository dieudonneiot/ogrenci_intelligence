import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const _steps = <_StepData>[
    _StepData(
      icon: Icons.person_add_alt,
      title: '1. Üye Ol',
      description: 'Hızlı ve ücretsiz kayıt ol, profilini tamamla.',
      bg: Color(0xFFDBEAFE),
      fg: Color(0xFF2563EB),
    ),
    _StepData(
      icon: Icons.menu_book,
      title: '2. Kurs Al',
      description: 'İlgi alanına göre kursları keşfet ve kaydol.',
      bg: Color(0xFFDCFCE7),
      fg: Color(0xFF16A34A),
    ),
    _StepData(
      icon: Icons.work_outline,
      title: '3. Staj/İş Bul',
      description: 'Sana uygun ilanlara başvur.',
      bg: Color(0xFFEDE9FE),
      fg: Color(0xFF6D28D9),
    ),
    _StepData(
      icon: Icons.emoji_events,
      title: '4. Puan Kazan',
      description: 'Her aktivitede puan kazan, sıralamada yüksel.',
      bg: Color(0xFFFEF3C7),
      fg: Color(0xFFB45309),
    ),
    _StepData(
      icon: Icons.card_giftcard,
      title: '5. Ödül Kazan',
      description: 'Puanlarını harika ödüllerle değiştir.',
      bg: Color(0xFFFEE2E2),
      fg: Color(0xFFDC2626),
    ),
  ];

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
                _Hero(
                  onPrimary: () => context.go(Routes.register),
                  onSecondary: () => context.go(Routes.courses),
                ),
                const SizedBox(height: 28),
                const _SectionHeader(
                  title: 'Adım Adım',
                  subtitle: 'Beş basit adımla kariyer yolculuğunu başlat.',
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final maxWidth = c.maxWidth;
                    final isWide = maxWidth >= 980;
                    final crossAxis = isWide ? 5 : (maxWidth >= 700 ? 2 : 1);
                    final itemWidth = (maxWidth - (crossAxis - 1) * 16) / crossAxis;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final step in _steps)
                          SizedBox(width: itemWidth, child: _StepCard(step: step)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                _SectionCard(
                  title: 'Detaylı Adımlar',
                  child: Column(
                    children: const [
                      _DetailStep(
                        index: '1',
                        title: 'Üyelik ve Profil',
                        description:
                            'E-posta adresinle hızlıca üye ol. Profilini doldurarak bölümünü ve ilgi alanlarını belirt.',
                        bullets: [
                          'Ad-soyad ve bölüm bilgilerini ekle',
                          'İlgi alanlarını seç',
                          'Kariyer hedeflerini belirt',
                        ],
                      ),
                      _DetailStep(
                        index: '2',
                        title: 'Eğitimler ve Kurslar',
                        description:
                            'Bölümüne ve ilgi alanlarına uygun kursları keşfet. Her kurs kaydında ve tamamlamada puan kazan.',
                        bullets: [
                          'Video içerikli eğitimler',
                          'Pratik projeler ve ödevler',
                          'Sertifika kazanma fırsatı',
                        ],
                      ),
                      _DetailStep(
                        index: '3',
                        title: 'Staj ve İş Başvuruları',
                        description:
                            'Sektördeki firmaların ilanlarına başvur. Kabul edildiğinde ekstra puanlar kazan.',
                        bullets: [
                          'Bölümüne özel ilanlar',
                          'Uzaktan ve yerinde çalışma seçenekleri',
                          'Değerlendirme ile ekstra puan',
                        ],
                      ),
                      _DetailStep(
                        index: '4',
                        title: 'Puan Sistemi',
                        description:
                            'Her gün giriş yap, aktivitelerini tamamla ve puan kazan. Bölüm ve genel sıralamada üst sıralara çık.',
                        highlights: [
                          _Highlight('Günlük Giriş', '+2 puan'),
                          _Highlight('Haftalık Seri', '+15 puan'),
                          _Highlight('Staj Tamamlama', '+100 puan'),
                          _Highlight('İlk 10', '+50 puan'),
                        ],
                      ),
                      _DetailStep(
                        index: '5',
                        title: 'Ödüller',
                        description:
                            'Biriktirdiğin puanları harika ödüllerle değiştir! Teknoloji ürünleri ve eğitim paketleri seni bekliyor.',
                        rewards: [
                          _Reward('Ücretsiz Eğitim Paketleri', '1000 puandan başlayan ödüller'),
                          _Reward('Teknoloji Ürünleri', '3000 puandan başlayan ödüller'),
                          _Reward('Yurt Dışı Gezileri', '5000 puandan başlayan ödüller'),
                          _Reward('Staj Garantisi', '1500 puandan başlayan ödüller'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _CtaCard(
                  onPrimary: () => context.go(Routes.register),
                  onSecondary: () => context.go(Routes.jobs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onPrimary, required this.onSecondary});

  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

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
            top: -40,
            child: _GlowCircle(color: Colors.white.withValues(alpha: 0.12), size: 140),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: _GlowCircle(color: Colors.white.withValues(alpha: 0.10), size: 120),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 900;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: isWide ? c.maxWidth * 0.55 : c.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Kariyer Yol Haritası',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nasıl Çalışır?',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Alanına özel kurslar, stajlar ve iş ilanları ile geleceğine sağlam adımlarla ilerle.',
                          style: TextStyle(color: Color(0xFFE0E7FF), height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: onPrimary,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF4C1D95),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Ücretsiz Kayıt Ol', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            OutlinedButton(
                              onPressed: onSecondary,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Kursları Gör', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: isWide ? c.maxWidth * 0.35 : c.maxWidth,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Bu sayfada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          SizedBox(height: 10),
                          _HeroBullet(text: 'Platform adımlarının özetini'),
                          _HeroBullet(text: 'Puan ve ödül mantığını'),
                          _HeroBullet(text: 'Başvuru sürecini'),
                          _HeroBullet(text: 'Hızlı başlangıç ipuçlarını'),
                        ],
                      ),
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

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HeroBullet extends StatelessWidget {
  const _HeroBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
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

class _StepData {
  const _StepData({
    required this.icon,
    required this.title,
    required this.description,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color bg;
  final Color fg;
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final _StepData step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: step.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(step.icon, size: 32, color: step.fg),
          ),
          const SizedBox(height: 10),
          Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(step.description, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailStep extends StatelessWidget {
  const _DetailStep({
    required this.index,
    required this.title,
    required this.description,
    this.bullets,
    this.highlights,
    this.rewards,
  });

  final String index;
  final String title;
  final String description;
  final List<String>? bullets;
  final List<_Highlight>? highlights;
  final List<_Reward>? rewards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(index, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6D28D9))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
                if (bullets != null) ...[
                  const SizedBox(height: 8),
                  for (final item in bullets!) _Bullet(text: item),
                ],
                if (highlights != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in highlights!) _HighlightCard(item: item),
                    ],
                  ),
                ],
                if (rewards != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in rewards!) _RewardCard(item: item),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF6B7280)))),
        ],
      ),
    );
  }
}

class _Highlight {
  const _Highlight(this.title, this.value);

  final String title;
  final String value;
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.item});

  final _Highlight item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(height: 4),
          Text(item.value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6D28D9))),
        ],
      ),
    );
  }
}

class _Reward {
  const _Reward(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.item});

  final _Reward item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(item.subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.onPrimary, required this.onSecondary});

  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Hazır mısın?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          const Text('Hemen üye ol, kariyerine yön vermeye başla!',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFE0E7FF))),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4C1D95),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Ücretsiz Kayıt Ol', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('İş İlanlarını Gör', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
