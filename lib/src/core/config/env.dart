// lib/src/core/config/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String _must(String key) {
    final v = dotenv.env[key];
    if (v == null || v.trim().isEmpty) {
      throw StateError('Missing env var: $key');
    }
    return v.trim();
  }

  static String get supabaseUrl => _must('SUPABASE_URL');
  static String get supabaseAnonKey => _must('SUPABASE_ANON_KEY');

  static String get deepLinkScheme =>
      (dotenv.env['DEEPLINK_SCHEME'] ?? 'com.ogrenciintelligence').trim();

  static Uri get deepLinkCallback => Uri.parse(
    (dotenv.env['DEEPLINK_CALLBACK'] ?? '$deepLinkScheme://login-callback')
        .trim(),
  );

  static Uri get deepLinkResetPassword => Uri.parse(
    (dotenv.env['DEEPLINK_RESET_PASSWORD'] ??
            '$deepLinkScheme://reset-password')
        .trim(),
  );

  static String get adminSetupKey => _must('ADMIN_SETUP_KEY');
}
