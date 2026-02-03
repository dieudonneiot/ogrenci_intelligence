import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../widgets/admin_layout.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.receipt_long_outlined,
        title: l10n.t(AppText.adminNavLogs),
      ),
      child: AdminPlaceholderCard(
        icon: Icons.receipt_long_outlined,
        title: l10n.t(AppText.adminNavLogs),
        subtitle: l10n.t(AppText.commonComingSoonSubtitle),
      ),
    );
  }
}
