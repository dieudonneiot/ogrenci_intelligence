import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/bootstrap.dart';
import 'src/core/localization/locale_controller.dart';
import 'src/core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background push handler (mobile only). Safe to call even if Firebase isn't configured yet.
  if (PushService.isSupported) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await bootstrap(); // loads env + initializes Supabase
  final savedLocale = await loadSavedLocale();

  runApp(
    ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWithValue(savedLocale),
      ],
      child: const App(),
    ),
  );
}
