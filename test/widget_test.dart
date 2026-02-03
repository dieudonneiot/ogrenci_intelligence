import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogrenci_intelligence/src/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://localhost', anonKey: 'test');
  });

  testWidgets('App boots (smoke test)', (WidgetTester tester) async {
    // Build the real app root
    await tester.pumpWidget(const ProviderScope(child: App()));

    // Let first frames build
    await tester.pump();

    // If we reach here without exceptions, boot is OK.
    expect(find.byType(App), findsOneWidget);
  });
}
