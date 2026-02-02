import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/company_providers.dart';
import '../../domain/company_models.dart';

class CompanyStatusCheck extends ConsumerStatefulWidget {
  const CompanyStatusCheck({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CompanyStatusCheck> createState() => _CompanyStatusCheckState();
}

class _CompanyStatusCheckState extends ConsumerState<CompanyStatusCheck> {
  bool _loading = true;
  CompanyStatus? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (auth == null || auth.userType != UserType.company || companyId == null) {
      setState(() {
        _loading = false;
        _error = 'Şirket hesabı bulunamadı.';
      });
      return;
    }

    try {
      final repo = ref.read(companyRepositoryProvider);
      final status = await repo.fetchCompanyStatus(companyId: companyId);
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchMail() async {
    final uri = Uri.parse('mailto:destek@platform.com');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _CenteredCard(
        icon: Icons.error_outline,
        iconBg: const Color(0xFFFEE2E2),
        iconFg: const Color(0xFFDC2626),
        title: 'Bir sorun oluştu',
        subtitle: _error!,
        actions: [
          ElevatedButton(
            onPressed: _load,
            child: const Text('Tekrar Dene'),
          ),
        ],
      );
    }

    final status = _status;
    if (status == null) {
      return _CenteredCard(
        icon: Icons.apartment_outlined,
        iconBg: const Color(0xFFE5E7EB),
        iconFg: const Color(0xFF6B7280),
        title: 'Şirket kaydı bulunamadı',
        subtitle: 'Şirket hesabınızı tamamlamak için kaydınızı oluşturun.',
        actions: [
          ElevatedButton(
            onPressed: () => context.go(Routes.companyRegister),
            child: const Text('Şirket Kaydı'),
          ),
        ],
      );
    }

    if (status.isBanned || status.approvalStatus == 'banned') {
      return _CenteredCard(
        icon: Icons.block,
        iconBg: const Color(0xFF111827),
        iconFg: Colors.white,
        title: 'Hesap askıya alındı',
        subtitle:
            'Şirket hesabınız platform kurallarının ihlali nedeniyle askıya alınmıştır. Destek ekibiyle iletişime geçin.',
        actions: [
          ElevatedButton.icon(
            onPressed: _launchMail,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Destek Ekibi'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827)),
          ),
        ],
      );
    }

    if (status.approvalStatus == 'pending') {
      return _CenteredCard(
        icon: Icons.schedule,
        iconBg: const Color(0xFFFEF3C7),
        iconFg: const Color(0xFFB45309),
        title: 'Onay bekleniyor',
        subtitle:
            'Şirket hesabınız onay sürecinde. En kısa sürede size dönüş yapacağız.',
        actions: [
          _InfoBox(
            title: 'Ne yapabilirsiniz?',
            items: const [
              'Şirket profilinizi tamamlayın',
              'Logo ve kapak görseli ekleyin',
              'İletişim bilgilerinizi güncelleyin',
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.go(Routes.companyProfile),
            child: const Text('Profili Düzenle'),
          ),
        ],
      );
    }

    if (status.approvalStatus == 'rejected') {
      return _CenteredCard(
        icon: Icons.cancel_outlined,
        iconBg: const Color(0xFFFEE2E2),
        iconFg: const Color(0xFFDC2626),
        title: 'Başvuru reddedildi',
        subtitle: 'Üzgünüz, şirket başvurunuz kabul edilmedi.',
        actions: [
          if ((status.rejectionReason ?? '').isNotEmpty)
            _InfoBox(
              title: 'Red Nedeni',
              items: [status.rejectionReason!],
              accent: const Color(0xFFFEE2E2),
              accentText: const Color(0xFF991B1B),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _launchMail,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Destek ile İletişim'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827)),
          ),
        ],
      );
    }

    if (status.approvalStatus == 'approved' && !status.hasActiveSubscription) {
      return _CenteredCard(
        icon: Icons.credit_card,
        iconBg: const Color(0xFFEDE9FE),
        iconFg: const Color(0xFF6D28D9),
        title: 'Abonelik gerekli',
        subtitle: 'İlan yayınlayabilmek için bir abonelik paketi seçmelisiniz.',
        actions: [
          _InfoBox(
            title: 'Hesabınız onaylandı',
            items: const ['Şimdi size uygun bir paket seçerek başlayabilirsiniz.'],
            accent: const Color(0xFFDCFCE7),
            accentText: const Color(0xFF166534),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.go(Routes.companyPricing),
            icon: const Icon(Icons.credit_card),
            label: const Text('Paketleri İncele'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
          ),
        ],
      );
    }

    return widget.child;
  }
}

class _CenteredCard extends StatelessWidget {
  const _CenteredCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, size: 40, color: iconFg),
                ),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 16),
                for (final item in actions) item,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.title,
    required this.items,
    this.accent = const Color(0xFFFFFBEB),
    this.accentText = const Color(0xFF92400E),
  });

  final String title;
  final List<String> items;
  final Color accent;
  final Color accentText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: accentText)),
          const SizedBox(height: 6),
          for (final item in items)
            Text('• $item', style: TextStyle(color: accentText)),
        ],
      ),
    );
  }
}
