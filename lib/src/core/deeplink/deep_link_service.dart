// lib/src/core/deeplink/deep_link_service.dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../routing/routes.dart';

class DeepLinkService {
  DeepLinkService({SupabaseClient? client, GoRouter? router})
      : _client = client ?? Supabase.instance.client,
        _router = router;

  final SupabaseClient _client;
  final GoRouter? _router;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Start listening to deep links.
  /// app_links ^6.x: `uriLinkStream` emits the initial link + subsequent links.
  Future<void> start() async {
    if (_sub != null) return;

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri)),
      onError: (e) {
        if (kDebugMode) debugPrint('DeepLink stream error: $e');
      },
    );
  }

  /// Stop listening (matches how you call it from app.dart)
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool _shouldHandle(Uri uri) {
    if (uri.scheme != Env.deepLinkScheme) return false;
    return uri.host == 'login-callback' || uri.host == 'reset-password';
  }

  Future<void> _handle(Uri uri) async {
    if (!_shouldHandle(uri)) return;

    if (kDebugMode) debugPrint('DeepLink received: $uri');

    // 1) Let Supabase parse tokens & establish session (recovery/login callback)
    try {
      await _client.auth.getSessionFromUrl(uri);
    } catch (e) {
      if (kDebugMode) debugPrint('getSessionFromUrl error: $e');
    }

    // 2) Reproduce React behavior: open the correct screen
    // - reset-password deep link should land on /reset-password
    // - login-callback can land on / and redirects will take over
    if (_router != null) {
      await Future.microtask(() {
        if (uri.host == 'reset-password') {
          _router.go(Routes.resetPassword);
        } else if (uri.host == 'login-callback') {
          _router.go(Routes.home);
        }
      });
    }
  }
}
