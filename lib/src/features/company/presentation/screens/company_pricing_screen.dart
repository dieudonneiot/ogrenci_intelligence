import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class CompanyPricingScreen extends StatelessWidget {
  const CompanyPricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final packages = <_Package>[
      _Package(
        name: l10n.t(AppText.companyPricingStarterName),
        price: l10n.t(AppText.companyPricingStarterPrice),
        description: l10n.t(AppText.companyPricingStarterDesc),
        features: [
          l10n.t(AppText.companyPricingStarterFeature1),
          l10n.t(AppText.companyPricingStarterFeature2),
          l10n.t(AppText.companyPricingStarterFeature3),
          l10n.t(AppText.companyPricingStarterFeature4),
        ],
        accent: Color(0xFF14B8A6),
      ),
      _Package(
        name: l10n.t(AppText.companyPricingProName),
        price: l10n.t(AppText.companyPricingProPrice),
        description: l10n.t(AppText.companyPricingProDesc),
        features: [
          l10n.t(AppText.companyPricingProFeature1),
          l10n.t(AppText.companyPricingProFeature2),
          l10n.t(AppText.companyPricingProFeature3),
          l10n.t(AppText.companyPricingProFeature4),
          l10n.t(AppText.companyPricingProFeature5),
        ],
        accent: Color(0xFF2563EB),
        highlighted: true,
      ),
      _Package(
        name: l10n.t(AppText.companyPricingEnterpriseName),
        price: l10n.t(AppText.companyPricingEnterprisePrice),
        description: l10n.t(AppText.companyPricingEnterpriseDesc),
        features: [
          l10n.t(AppText.companyPricingEnterpriseFeature1),
          l10n.t(AppText.companyPricingEnterpriseFeature2),
          l10n.t(AppText.companyPricingEnterpriseFeature3),
          l10n.t(AppText.companyPricingEnterpriseFeature4),
          l10n.t(AppText.companyPricingEnterpriseFeature5),
        ],
        accent: const Color(0xFF0F172A),
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
                  Text(
                    l10n.t(AppText.companyPricingTitle),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t(AppText.companyPricingSubtitle),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pkg.highlighted ? pkg.accent : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pkg.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            pkg.description,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pkg.price,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: pkg.accent,
            ),
          ),
          const SizedBox(height: 14),
          for (final feature in pkg.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: pkg.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.t(AppText.companyPricingSalesContacted)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: pkg.accent),
              child: Text(
                l10n.t(AppText.companyPricingSelectPackage),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
