import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../routing/routes.dart';
import '../supabase/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Best-effort init. Background handler must not crash.
  try {
    await PushService.ensureFirebaseInitialized();
  } catch (_) {}
}

class PushService {
  PushService({
    required this.router,
  });

  final GoRouter router;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  static bool _firebaseReady = false;

  static bool get isSupported {
    if (kIsWeb) return false; // web requires FirebaseOptions + SW; keep mobile-only for now
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<bool> ensureFirebaseInitialized() async {
    if (!isSupported) return false;
    if (_firebaseReady) return true;
    await Firebase.initializeApp();
    _firebaseReady = true;
    return true;
  }

  Future<void> start() async {
    try {
      if (!await ensureFirebaseInitialized()) return;
    } catch (_) {
      return;
    }

    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // iOS: permissions + foreground presentation
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Handle app opened from terminated by notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleNavigation(initial);
    }

    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigation);

    // Foreground messages: keep minimal (OS does not show notification on iOS without presentation options).
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
      // no-op (optional: show in-app toast/snackbar later)
    });

    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _upsertTokenIfAuthed(token);
    });

    // initial token registration (if authenticated)
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _upsertTokenIfAuthed(token);
    }
  }

  Future<void> stop() async {
    await _tokenSub?.cancel();
    await _openSub?.cancel();
    await _messageSub?.cancel();
    _tokenSub = null;
    _openSub = null;
    _messageSub = null;
  }

  Future<void> onAuthChanged(AuthViewState auth) async {
    if (!await ensureFirebaseInitialized()) return;
    if (!auth.isAuthenticated) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _upsertTokenIfAuthed(token);
    }
  }

  Future<void> _upsertTokenIfAuthed(String token) async {
    final user = SupabaseService.client.auth.currentUser;
    final session = SupabaseService.client.auth.currentSession;
    if (user == null || session == null) return;
    if (user.emailConfirmedAt == null) return;

    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await SupabaseService.client.rpc(
        'upsert_my_push_token',
        params: {
          'p_token': token.trim(),
          'p_platform': platform,
          'p_device_id': null,
        },
      );
    } catch (_) {
      // Best-effort: if SQL not installed yet, don't block the app.
    }
  }

  void _handleNavigation(RemoteMessage message) {
    final data = message.data;
    final route = (data['route'] ?? '').toString().trim();

    if (route.isNotEmpty) {
      router.go(route);
      return;
    }

    final type = (data['type'] ?? '').toString().trim();
    if (type == 'focus_check') {
      final id = (data['focus_check_id'] ?? '').toString().trim();
      if (id.isNotEmpty) {
        router.go('${Routes.focusCheck}?id=$id');
      } else {
        router.go(Routes.focusCheck);
      }
      return;
    }
  }
}
