import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../widgets/admin_layout.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.bar_chart_outlined,
        title: l10n.t(AppText.adminNavReports),
      ),
      child: AdminPlaceholderCard(
        icon: Icons.bar_chart_outlined,
        title: l10n.t(AppText.adminNavReports),
        subtitle: l10n.t(AppText.commonComingSoonSubtitle),
      ),
    );
  }
}
