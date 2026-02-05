import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                if (l10n.locale.languageCode != 'tr') ...[
                  const SizedBox(height: 12),
                  _NoticeCard(text: l10n.t(AppText.legalTurkishOnlyNote)),
                ],
                const SizedBox(height: 18),
                const _Toc(),
                const SizedBox(height: 18),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Paragraph(
                        'Öğrenci Intelligence platformunu kullanarak aşağıdaki kullanım şartlarını kabul etmiş sayılırsınız. Lütfen bu şartları dikkatlice okuyunuz.',
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.person_outline,
                        title: 'Hesap ve Üyelik',
                      ),
                      _BulletList(
                        items: [
                          'Kayıt sırasında doğru ve güncel bilgiler vermelisiniz.',
                          'Bir kişi yalnızca bir hesap açabilir.',
                          'Hesap güvenliğinizden siz sorumlusunuz.',
                          '18 yaş altı kullanıcılar veli izniyle kayıt olabilir.',
                        ],
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.fact_check_outlined,
                        title: 'Platform Kullanımı',
                      ),
                      _Paragraph(
                        'Platform, eğitim ve kariyer gelişimi amaçlı kullanılmalıdır:',
                      ),
                      _HighlightBox(
                        items: [
                          'İçerikleri kişisel kullanım için görüntüleyebilirsiniz.',
                          'Paylaşımlarınızın doğruluğundan siz sorumlusunuz.',
                          'Diğer kullanıcılara saygılı davranmalısınız.',
                        ],
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Puan ve Ödül Sistemi',
                      ),
                      _BulletList(
                        items: [
                          'Puan kazanmak için hile veya bot kullanımı yasaktır.',
                          'Puanlar devredilemez ve üçüncü kişilerle takas edilemez.',
                          'Şüpheli puan artışları incelenir ve geri alınabilir.',
                        ],
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.report_gmailerrorred,
                        title: 'Yasaklı Davranışlar',
                      ),
                      _BulletList(
                        items: [
                          'Sahte veya yanıltıcı profil oluşturmak',
                          'Hakaret, tehdit veya taciz içerikleri paylaşmak',
                          'Telif haklarını ihlal eden içerikler yayımlamak',
                          'Platformun güvenliğini tehlikeye atmak',
                          'Yasalara aykırı faaliyetlerde bulunmak',
                        ],
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.shield_outlined,
                        title: 'İçerik Hakları',
                      ),
                      _SubTitle('Kullanıcı İçerikleri'),
                      _Paragraph(
                        'Platforma yüklediğiniz içeriklerin (CV, proje, yorum vb.) sorumluluğu size aittir. Bu içerikleri yükleyerek, platformun bunları görüntüleme ve hizmet sunma amacıyla kullanma hakkını kabul etmiş olursunuz.',
                      ),
                      SizedBox(height: 12),
                      _SubTitle('Platform İçerikleri'),
                      _Paragraph(
                        'Platform üzerindeki tüm içerikler (kurslar, tasarım, yazılım, metinler) telif hakkı ile korunur. İzinsiz kopyalama, dağıtma veya değiştirme yasaktır.',
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(title: 'Sorumluluk Reddi'),
                      _WarningBox(
                        text:
                            'Platform "olduğu gibi" sunulur ve iş veya staj bulma garantisi verilmez. Kullanıcılar arasındaki anlaşmazlıklardan ve platform kullanımından doğabilecek zararlardan sorumlu değiliz.',
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(title: 'Askıya Alma ve Fesih'),
                      _Paragraph(
                        'Aşağıdaki durumlarda hesabınız askıya alınabilir veya kapatılabilir:',
                      ),
                      _BulletList(
                        items: [
                          'Kullanım şartlarının ihlali',
                          'Sahte veya yanıltıcı bilgi paylaşımı',
                          'Diğer kullanıcıları taciz veya rahatsız etme',
                          'Platform güvenliğini tehdit eden davranışlar',
                        ],
                      ),
                      SizedBox(height: 18),
                      _SectionTitle(title: 'Değişiklikler'),
                      _Paragraph(
                        'Bu kullanım şartları zaman zaman güncellenebilir. Önemli değişiklikler olması durumunda size e-posta veya platform üzerinden bildirim yapılacaktır.',
                      ),
                      SizedBox(height: 18),
                      Divider(),
                      SizedBox(height: 8),
                      _SectionTitle(title: 'İletişim'),
                      _Paragraph(
                        'Kullanım şartları hakkında sorularınız için:',
                      ),
                      _ContactBox(),
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
    final l10n = AppLocalizations.of(context);
    final lastUpdated = DateTime(2026, 2, 2);
    final dateText = MaterialLocalizations.of(
      context,
    ).formatFullDate(lastUpdated);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFEDE9FE),
            child: Icon(
              Icons.description_outlined,
              color: Color(0xFF6D28D9),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(AppText.linkTerms),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.legalLastUpdated(dateText),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
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
          _Chip(label: 'Üyelik'),
          _Chip(label: 'Kullanım'),
          _Chip(label: 'Puan/Ödül'),
          _Chip(label: 'Yasaklı Davranış'),
          _Chip(label: 'İçerik Hakları'),
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
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF6D28D9),
        ),
      ),
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
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
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
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
    );
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
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
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
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF4C1D95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF92400E), height: 1.4),
      ),
    );
  }
}

class _ContactBox extends StatelessWidget {
  const _ContactBox();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.t(AppText.contactEmailTitle)}: info@ogrenciintelligence.com',
            style: const TextStyle(color: Color(0xFF374151)),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.t(AppText.contactPhoneTitle)}: +90 (212) 345 67 89',
            style: const TextStyle(color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}
