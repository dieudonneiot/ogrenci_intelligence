// lib/core/deeplink/deep_link_service.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class DeepLinkService {
  DeepLinkService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    // Initial link
    try {
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        await _handle(uri);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink initial error: $e');
    }

    // Stream links
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri)),
      onError: (e) {
        if (kDebugMode) debugPrint('DeepLink stream error: $e');
      },
    );
  }

  bool _shouldHandle(Uri uri) {
    if (uri.scheme != Env.deepLinkScheme) return false;
    return uri.host == 'login-callback' || uri.host == 'reset-password';
  }

  Future<void> _handle(Uri uri) async {
    if (!_shouldHandle(uri)) return;

    try {
      await _client.auth.getSessionFromUrl(uri);
    } catch (e) {
      if (kDebugMode) debugPrint('getSessionFromUrl error: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
