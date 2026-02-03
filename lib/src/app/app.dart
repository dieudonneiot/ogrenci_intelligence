import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deeplink/deep_link_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
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

    final router = ref.read(goRouterProvider);

    _deepLinks = DeepLinkService(
      client: SupabaseService.client,
      router: router,
    );

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
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateTitle: (context) => AppLocalizations.of(context).t(AppText.brandName),
      title: AppLocalizations.of(context).t(AppText.brandName),
      routerConfig: router,
    );
  }
}
