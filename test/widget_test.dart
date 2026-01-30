import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogrenci_intelligence/src/app/app.dart';

void main() {
  testWidgets('App boots (smoke test)', (WidgetTester tester) async {
    // Build the real app root
    await tester.pumpWidget(const ProviderScope(child: App()));

    // Let first frames build
    await tester.pump();

    // If we reach here without exceptions, boot is OK.
    expect(find.byType(App), findsOneWidget);
  });
}
