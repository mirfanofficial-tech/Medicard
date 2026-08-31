import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicard/src/app.dart';

void main() {
  testWidgets('landing screen offers both roles', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediCardApp()));
    await tester.pumpAndSettle();

    expect(find.text('MediCard'), findsOneWidget);
    expect(find.text("I'm a patient"), findsOneWidget);
    expect(find.text("I'm a doctor"), findsOneWidget);
  });

  testWidgets('tapping patient navigates to patient home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediCardApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a patient"));
    await tester.pumpAndSettle();

    expect(find.text('Patient'), findsOneWidget);
  });
}
