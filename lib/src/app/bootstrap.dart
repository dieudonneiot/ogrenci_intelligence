import '../core/config/env.dart';
import '../core/push/push_service.dart';
import '../core/supabase/supabase_service.dart';

Future<void> bootstrap() async {
  await Env.load();

  // Push (mobile only). Best-effort so the app still runs without Firebase config.
  try {
    await PushService.ensureFirebaseInitialized();
  } catch (_) {}

  await SupabaseService.initialize(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
  );
}
