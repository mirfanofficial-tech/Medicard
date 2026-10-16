import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicard/src/app.dart';
import 'package:medicard/src/core/api_client.dart';

/// In-memory token store so widget tests don't touch platform secure storage.
class _FakeTokenStore implements TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<String?> get accessToken async => _access;

  @override
  Future<String?> get refreshToken async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

Widget _app() => ProviderScope(
      overrides: [tokenStoreProvider.overrideWithValue(_FakeTokenStore())],
      child: const MediCardApp(),
    );

void main() {
  testWidgets('landing screen offers get-started and a doctor path', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('MediCard'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text("I'm a doctor"), findsOneWidget);
  });

  testWidgets('Get Started opens the phone OTP sign-in', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Send code'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Phone number'), findsOneWidget);
  });

  testWidgets('doctor path opens registration with the licence-review notice',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a doctor"));
    await tester.pumpAndSettle();

    expect(find.text('Doctor registration'), findsOneWidget);
    expect(find.textContaining('reviewed against the licence register'), findsOneWidget);
  });

  for (final size in const [Size(360, 740), Size(1280, 800)]) {
    for (final route in const ['/patient/auth', '/doctor/auth']) {
      testWidgets('$route renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        final cta = find.text(route == '/patient/auth' ? 'Get Started' : "I'm a doctor");
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        await tester.tap(cta);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsWidgets);
      });
    }
  }
}
