import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/bootstrap.dart';
import 'src/core/localization/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
