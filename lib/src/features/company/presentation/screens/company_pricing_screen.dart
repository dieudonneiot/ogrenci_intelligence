import 'package:flutter/material.dart';

class CompanyPricingScreen extends StatelessWidget {
  const CompanyPricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final packages = <_Package>[
      const _Package(
        name: 'Başlangıç',
        price: '₺1999 / ay',
        description: 'Küçük işletmeler için ideal',
        features: [
          '5 aktif ilan',
          'Temel raporlama',
          'E-posta desteği',
          'Aylık 50 CV görüntüleme',
        ],
        accent: Color(0xFF6D28D9),
      ),
      const _Package(
        name: 'Profesyonel',
        price: '₺2999 / ay',
        description: 'Büyüyen şirketler için',
        features: [
          '20 aktif ilan',
          'Gelişmiş raporlama',
          'Öncelikli destek',
          'Aylık 500 CV görüntüleme',
          'Aday filtreleme araçları',
        ],
        accent: Color(0xFF2563EB),
        highlighted: true,
      ),
      const _Package(
        name: 'Kurumsal',
        price: 'Özel Fiyat',
        description: 'Büyük organizasyonlar için',
        features: [
          'Sınırsız ilan',
          'Özel raporlar',
          '7/24 destek',
          'Sınırsız CV görüntüleme',
          'API erişimi',
        ],
        accent: Color(0xFF111827),
      ),
    ];

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paketler ve Fiyatlar',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    'Şirketiniz için en uygun paketi seçin. Yeni paketler için bizimle iletişime geçebilirsiniz.',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (_, c) {
                      final crossAxis = c.maxWidth >= 980
                          ? 3
                          : c.maxWidth >= 720
                              ? 2
                              : 1;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxis,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95,
                        children: [
                          for (final pkg in packages) _PackageCard(pkg: pkg),
                        ],
                      );
                    },
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

class _Package {
  const _Package({
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    required this.accent,
    this.highlighted = false,
  });

  final String name;
  final String price;
  final String description;
  final List<String> features;
  final Color accent;
  final bool highlighted;
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg});

  final _Package pkg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pkg.highlighted ? pkg.accent : const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pkg.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(pkg.description,
              style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(pkg.price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: pkg.accent)),
          const SizedBox(height: 14),
          for (final feature in pkg.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: pkg.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature, style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Satış ekibi sizinle iletişime geçecek.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: pkg.accent),
              child: const Text('Paketi Seç', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
