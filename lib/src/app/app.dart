import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deeplink/deep_link_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/push/push_service.dart';
import '../core/routing/app_router.dart';
import '../core/supabase/supabase_service.dart';
import '../core/theme/app_scroll_behavior.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  DeepLinkService? _deepLinks;
  PushService? _push;
  ProviderSubscription<AsyncValue<AuthViewState>>? _authSub;

  @override
  void initState() {
    super.initState();

    final router = ref.read(goRouterProvider);

    _deepLinks = DeepLinkService(
      client: SupabaseService.client,
      router: router,
    );

    unawaited(_deepLinks!.start());

    _push = PushService(router: router);
    unawaited(_push!.start());

    _authSub = ref.listenManual<AsyncValue<AuthViewState>>(
      authViewStateProvider,
      (prev, next) {
        final auth = next.valueOrNull;
        if (auth == null) return;
        unawaited(_push?.onAuthChanged(auth) ?? Future.value());
      },
    );
  }

  @override
  void dispose() {
    unawaited(_deepLinks?.stop() ?? Future.value());
    unawaited(_push?.stop() ?? Future.value());
    _authSub?.close();
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
      onGenerateTitle: (context) =>
          AppLocalizations.of(context).t(AppText.brandName),
      title: AppLocalizations.of(context).t(AppText.brandName),
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const AppScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
