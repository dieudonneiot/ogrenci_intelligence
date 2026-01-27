import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart'; // for unawaited
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  DeepLinkService(this._client);

  final SupabaseClient _client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    // app_links 6.x: use getInitialLink() (not getInitialAppLink)
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
      // Supabase parses tokens from deep link and restores session if applicable.
      await _client.auth.getSessionFromUrl(uri);
    } catch (_) {
      // Ignore expired/invalid links.
    }
  }
}
