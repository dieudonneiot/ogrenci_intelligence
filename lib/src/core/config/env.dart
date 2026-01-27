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

  // We'll use these later for deep links (safe defaults)
  static String get deepLinkScheme =>
      (dotenv.env['DEEPLINK_SCHEME'] ?? 'ogrenci-intelligence').trim();

  static Uri get deepLinkCallback => Uri.parse(
        (dotenv.env['DEEPLINK_CALLBACK'] ??
                '$deepLinkScheme://login-callback')
            .trim(),
      );
}
