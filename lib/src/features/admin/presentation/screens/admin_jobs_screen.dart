import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../widgets/admin_layout.dart';

class AdminJobsScreen extends StatelessWidget {
  const AdminJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminPageScaffold(
      header: AdminPageHeader(
        icon: Icons.work_outline,
        title: l10n.t(AppText.adminNavJobs),
      ),
      child: AdminPlaceholderCard(
        icon: Icons.work_outline,
        title: l10n.t(AppText.adminNavJobs),
        subtitle: l10n.t(AppText.commonComingSoonSubtitle),
      ),
    );
  }
}
