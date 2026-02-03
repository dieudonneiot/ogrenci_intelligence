import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../widgets/admin_layout.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.settings_outlined,
        title: l10n.t(AppText.adminNavSettings),
      ),
      child: AdminPlaceholderCard(
        icon: Icons.settings_outlined,
        title: l10n.t(AppText.adminNavSettings),
        subtitle: l10n.t(AppText.commonComingSoonSubtitle),
      ),
    );
  }
}
