import '../core/config/env.dart';
import '../core/supabase/supabase_service.dart';

Future<void> bootstrap() async {
  await Env.load();

  await SupabaseService.initialize(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
  );
}
