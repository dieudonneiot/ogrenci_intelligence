import 'package:flutter/material.dart';

import '../widgets/admin_layout.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        icon: Icons.bar_chart_outlined,
        title: 'Raporlar',
      ),
      child: const AdminPlaceholderCard(
        icon: Icons.bar_chart_outlined,
        title: 'Raporlar',
        subtitle: 'Bu sayfa yakında aktif olacak',
      ),
    );
  }
}
