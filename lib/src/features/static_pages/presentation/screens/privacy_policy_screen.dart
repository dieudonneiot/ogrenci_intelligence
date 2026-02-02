import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                const SizedBox(height: 18),
                const _Toc(),
                const SizedBox(height: 18),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Paragraph(
                        'Öğrenci Intelligence olarak, kullanıcılarımızın gizliliğini korumak en önemli önceliklerimizden biridir. Bu gizlilik politikası, kişisel verilerinizin nasıl toplandığını, kullanıldığını, saklandığını ve korunduğunu açıklar.',
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(icon: Icons.storage_outlined, title: 'Toplanan Bilgiler'),
                      _SubTitle('Kayıt Bilgileri'),
                      _BulletList(items: [
                        'Ad ve soyad',
                        'E-posta adresi',
                        'Telefon numarası (isteğe bağlı)',
                        'Üniversite ve bölüm bilgisi',
                        'Mezuniyet yılı',
                      ]),
                      SizedBox(height: 12),
                      _SubTitle('Kullanım Verileri'),
                      _BulletList(items: [
                        'Platform üzerindeki aktiviteleriniz',
                        'Tamamladığınız kurslar',
                        'Başvurduğunuz iş ve staj ilanları',
                        'Kazandığınız puanlar ve rozetler',
                      ]),
                      SizedBox(height: 12),
                      _SubTitle('Teknik Bilgiler'),
                      _BulletList(items: [
                        'IP adresi',
                        'Tarayıcı türü ve versiyonu',
                        'İşletim sistemi',
                        'Ziyaret tarihi ve saati',
                      ]),
                      SizedBox(height: 18),
                      _SectionTitle(icon: Icons.visibility_outlined, title: 'Bilgilerin Kullanımı'),
                      _Paragraph('Topladığımız bilgileri şu amaçlarla kullanırız:'),
                      _BulletList(items: [
                        'Size daha iyi bir kullanıcı deneyimi sunmak',
                        'İlgi alanlarınıza uygun kurs ve iş önerileri yapmak',
                        'Platform güvenliğini sağlamak',
                        'İstatistiksel analizler yapmak',
                        'Yasal yükümlülüklerimizi yerine getirmek',
                        'Size bilgilendirme e-postaları göndermek (izninizle)',
                      ]),
                      SizedBox(height: 18),
                      _SectionTitle(icon: Icons.lock_outline, title: 'Bilgi Güvenliği'),
                      _Paragraph('Kişisel verilerinizin güvenliği için aşağıdaki önlemleri alıyoruz:'),
                      SizedBox(height: 8),
                      _HighlightBox(items: [
                        'SSL şifreleme teknolojisi',
                        'Güvenli veri merkezleri',
                        'Düzenli güvenlik testleri',
                        'Sınırlı erişim yetkileri',
                        'KVKK uyumlu veri işleme',
                      ]),
                      SizedBox(height: 18),
                      _SectionTitle(icon: Icons.verified_user_outlined, title: 'Üçüncü Taraflarla Paylaşım'),
                      _Paragraph('Kişisel verilerinizi aşağıdaki durumlar dışında üçüncü taraflarla paylaşmayız:'),
                      _BulletList(items: [
                        'Açık izniniz olması durumunda',
                        'Yasal zorunluluklar gerektiğinde',
                        'Başvurduğunuz işveren firmalara (sadece başvuru bilgileri)',
                        'Hizmet sağlayıcılarımıza (gizlilik sözleşmesi kapsamında)',
                      ]),
                      SizedBox(height: 18),
                      _SectionTitle(title: 'Çerezler (Cookies)'),
                      _Paragraph('Platformumuzda kullanıcı deneyimini iyileştirmek için çerezler kullanıyoruz:'),
                      SizedBox(height: 8),
                      _MiniCard(title: 'Zorunlu Çerezler', subtitle: 'Platform işlevselliği için gerekli'),
                      _MiniCard(title: 'Analitik Çerezler', subtitle: 'Kullanım istatistikleri için'),
                      _MiniCard(title: 'Tercih Çerezleri', subtitle: 'Kişiselleştirilmiş deneyim için'),
                      SizedBox(height: 18),
                      _SectionTitle(title: 'Haklarınız'),
                      _Paragraph('KVKK kapsamında aşağıdaki haklara sahipsiniz:'),
                      _BulletList(items: [
                        'Kişisel verilerinizin işlenip işlenmediğini öğrenme',
                        'İşlenen verileriniz hakkında bilgi talep etme',
                        'İşleme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme',
                        'Yanlış verilerin düzeltilmesini isteme',
                        'Verilerinizin silinmesini veya yok edilmesini isteme',
                        'İşlenen verilerin aktarıldığı üçüncü kişileri bilme',
                      ]),
                      SizedBox(height: 18),
                      _SectionTitle(icon: Icons.info_outline, title: 'İletişim'),
                      _Paragraph('Gizlilik politikamız hakkında sorularınız için bizimle iletişime geçebilirsiniz:'),
                      _ContactBox(),
                      SizedBox(height: 18),
                      Divider(),
                      SizedBox(height: 8),
                      Text(
                        'Bu gizlilik politikası zaman zaman güncellenebilir. Önemli değişiklikler olması durumunda size e-posta veya platform üzerinden bildirim yapılacaktır.',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      ),
                    ],
                  ),
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
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFEDE9FE),
            child: Icon(Icons.shield_outlined, color: Color(0xFF6D28D9), size: 28),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gizlilik Politikası',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                SizedBox(height: 4),
                Text('Son güncellenme: 2 Şubat 2026', style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toc extends StatelessWidget {
  const _Toc();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: const [
          _Chip(label: 'Toplanan Bilgiler'),
          _Chip(label: 'Kullanım Amaçları'),
          _Chip(label: 'Güvenlik'),
          _Chip(label: 'Çerezler'),
          _Chip(label: 'Haklarınız'),
          _Chip(label: 'İletişim'),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6D28D9))),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFF6D28D9)),
          const SizedBox(width: 8),
        ],
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5));
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF6B7280))),
                  Expanded(child: Text(item, style: const TextStyle(color: Color(0xFF6B7280)))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HighlightBox extends StatelessWidget {
  const _HighlightBox({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(color: Color(0xFF4C1D95), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ContactBox extends StatelessWidget {
  const _ContactBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('E-posta: privacy@ogrenciintelligence.com', style: TextStyle(color: Color(0xFF374151))),
          SizedBox(height: 4),
          Text('Telefon: +90 (212) 345 67 89', style: TextStyle(color: Color(0xFF374151))),
          SizedBox(height: 4),
          Text('Adres: Teknokent, İnovasyon Cad. No:123, Beşiktaş, İstanbul',
              style: TextStyle(color: Color(0xFF374151))),
        ],
      ),
    );
  }
}
