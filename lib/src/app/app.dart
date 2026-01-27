import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deeplink/deep_link_service.dart';
import '../core/routing/app_router.dart';
import '../core/supabase/supabase_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  DeepLinkService? _deepLinks;

  @override
  void initState() {
    super.initState();
    _deepLinks = DeepLinkService(SupabaseService.client);
    unawaited(_deepLinks!.start());
  }

  @override
  void dispose() {
    unawaited(_deepLinks?.stop() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Öğrenci Intelligence',
      routerConfig: router,
    );
  }
}