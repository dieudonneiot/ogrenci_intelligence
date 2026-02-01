import 'package:flutter/material.dart';

import '../widgets/admin_layout.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        icon: Icons.person_outline,
        title: 'Admin Profili',
      ),
      child: const AdminPlaceholderCard(
        icon: Icons.person_outline,
        title: 'Profil Ayarları',
        subtitle: 'Bu sayfa yakında aktif olacak',
      ),
    );
  }
}
