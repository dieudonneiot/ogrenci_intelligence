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

  static String _mustAny(List<String> keys) {
    for (final key in keys) {
      final v = dotenv.env[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    throw StateError('Missing env var (any of): ${keys.join(', ')}');
  }

  // Support both naming conventions. Supabase dashboard secrets may disallow
  // creating variables starting with SUPABASE_, but local .env files can use
  // either.
  static String get supabaseUrl => _mustAny(['SUPABASE_URL', 'BASE_URL']);
  static String get supabaseAnonKey =>
      _mustAny(['SUPABASE_ANON_KEY', 'BASE_ANON_KEY']);

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
