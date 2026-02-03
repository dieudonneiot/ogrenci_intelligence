import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../widgets/admin_layout.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.person_outline,
        title: l10n.t(AppText.adminNavProfile),
      ),
      child: AdminPlaceholderCard(
        icon: Icons.person_outline,
        title: l10n.t(AppText.adminNavProfile),
        subtitle: l10n.t(AppText.commonComingSoonSubtitle),
      ),
    );
  }
}
