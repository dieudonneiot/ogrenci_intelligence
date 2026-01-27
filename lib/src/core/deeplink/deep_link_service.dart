import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  DeepLinkService(this._client);

  final SupabaseClient _client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _handle(initial);
    }

    _sub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handle(uri));
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _handle(Uri uri) async {
    try {
      final s = uri.toString();
      final looksAuth = s.contains('access_token=') ||
          s.contains('refresh_token=') ||
          s.contains('type=recovery') ||
          s.contains('code=');

      if (!looksAuth) return;

      await _client.auth.getSessionFromUrl(uri);
    } catch (e) {
      if (kDebugMode) {
        // print('Deep link parse failed: $e');
      }
    }
  }
}
