import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../widgets/admin_layout.dart';

class AdminSubscriptionsScreen extends StatelessWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.credit_card_outlined,
        title: l10n.t(AppText.adminNavSubscriptions),
      ),
      child: AdminPlaceholderCard(
        icon: Icons.credit_card_outlined,
        title: l10n.t(AppText.adminNavSubscriptions),
        subtitle: l10n.t(AppText.commonComingSoonSubtitle),
      ),
    );
  }
}
