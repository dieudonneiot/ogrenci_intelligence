import 'package:flutter/material.dart';

import '../widgets/admin_layout.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        icon: Icons.receipt_long_outlined,
        title: 'İşlem Kayıtları',
      ),
      child: const AdminPlaceholderCard(
        icon: Icons.receipt_long_outlined,
        title: 'İşlem Kayıtları',
        subtitle: 'Bu sayfa yakında aktif olacak',
      ),
    );
  }
}
