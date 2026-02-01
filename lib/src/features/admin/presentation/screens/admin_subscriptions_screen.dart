import 'package:flutter/material.dart';

import '../widgets/admin_layout.dart';

class AdminSubscriptionsScreen extends StatelessWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        icon: Icons.credit_card_outlined,
        title: 'Abonelik Yönetimi',
      ),
      child: const AdminPlaceholderCard(
        icon: Icons.credit_card_outlined,
        title: 'Abonelik Yönetimi',
        subtitle: 'Bu sayfa yakında aktif olacak',
      ),
    );
  }
}
