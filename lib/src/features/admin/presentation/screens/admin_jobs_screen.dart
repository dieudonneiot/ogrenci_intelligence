import 'package:flutter/material.dart';

import '../widgets/admin_layout.dart';

class AdminJobsScreen extends StatelessWidget {
  const AdminJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        icon: Icons.work_outline,
        title: 'İlan Yönetimi',
      ),
      child: const AdminPlaceholderCard(
        icon: Icons.work_outline,
        title: 'İlan Yönetimi',
        subtitle: 'Bu sayfa yakında aktif olacak',
      ),
    );
  }
}
