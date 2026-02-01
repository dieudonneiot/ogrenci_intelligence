import 'package:flutter/material.dart';

import '../widgets/admin_layout.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        icon: Icons.settings_outlined,
        title: 'Ayarlar',
      ),
      child: const AdminPlaceholderCard(
        icon: Icons.settings_outlined,
        title: 'Sistem Ayarları',
        subtitle: 'Bu sayfa yakında aktif olacak',
      ),
    );
  }
}
