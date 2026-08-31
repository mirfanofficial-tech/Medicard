import 'package:flutter/widgets.dart';
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
  testWidgets('landing screen offers both roles', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('MediCard'), findsOneWidget);
    expect(find.text("I'm a patient"), findsOneWidget);
    expect(find.text("I'm a doctor"), findsOneWidget);
  });

  testWidgets('patient button opens the OTP sign-in screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a patient"));
    await tester.pumpAndSettle();

    expect(find.text('Patient sign in'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('doctor button opens registration with the licence-review notice',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a doctor"));
    await tester.pumpAndSettle();

    expect(find.text('Doctor registration'), findsOneWidget);
    expect(find.textContaining('reviewed against the licence register'), findsOneWidget);
  });
}
