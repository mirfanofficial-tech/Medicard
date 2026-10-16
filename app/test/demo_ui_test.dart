// Renders the real screens against the static demo backend.
// Run with:  flutter test test/demo_ui_test.dart --dart-define=DEMO=true
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicard/src/app.dart';
import 'package:medicard/src/core/api_client.dart';
import 'package:medicard/src/core/env.dart';
import 'package:medicard/src/demo/demo_data.dart';
import 'package:medicard/src/demo/demo_state.dart';
import 'package:medicard/src/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_fonts.dart';

class _Store implements TokenStore {
  _Store(this._access);
  String? _access;
  @override
  Future<String?> get accessToken async => _access;
  @override
  Future<String?> get refreshToken async => _access == null ? null : '$_access-refresh';
  @override
  Future<void> save({required String access, required String refresh}) async => _access = access;
  @override
  Future<void> clear() async => _access = null;
}

Future<ProviderContainer> _boot(WidgetTester t, String token) async {
  t.view.physicalSize = const Size(1600, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(_Store(token))]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MediCardApp()));
  await t.pumpAndSettle(const Duration(milliseconds: 400));
  return c;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  const skip = !Env.demo;

  setUpAll(loadRealFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoState.reset();
  });

  testWidgets('patient home shows next medicine, summary, reports and ask box', (t) async {
    await _boot(t, 'demo-patient');
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('NEXT MEDICINE'), findsOneWidget);
    expect(find.text('Your health, simply'), findsOneWidget);
    expect(find.text('Sugar test (HbA1c)'), findsOneWidget);
    expect(find.text('Load more reports'), findsOneWidget);
    expect(find.text('Ask your health assistant…'), findsOneWidget);
    expect(find.text('My numbers'), findsOneWidget);
    expect(find.text('Emergency card'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget); // floating button on every tab
  }, skip: skip);

  testWidgets('care plan page renders with the doctor\'s advice', (t) async {
    final c = await _boot(t, 'demo-patient');
    c.read(routerProvider).go('/patient/care-plan');
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('What to eat'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
  }, skip: skip);

  testWidgets('doctor dashboard lists today\'s patients; only Ayesha is active', (t) async {
    await _boot(t, 'demo-doctor');
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text("Today's patients"), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsWidgets);
    expect(find.text('Zain Malik'), findsOneWidget);
    expect(find.text('Waiting'), findsWidgets);
  }, skip: skip);

  testWidgets('after consent the doctor sees the full patient dashboard', (t) async {
    final c = await _boot(t, 'demo-doctor');
    final s = await DemoState.load();
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
    c.read(routerProvider).go('/doctor/patients/$demoPatientId/records');
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Ayesha Khan'), findsWidgets);
    expect(find.text('Medical History Timeline'), findsOneWidget);
    expect(find.text('Latest Lab Results'), findsOneWidget);
    expect(find.text('AI Health Insights'), findsOneWidget);
    expect(find.textContaining('Before you prescribe'), findsOneWidget);
  }, skip: skip);

  testWidgets('AI panel offers tap-to-ask questions', (t) async {
    final c = await _boot(t, 'demo-doctor');
    final s = await DemoState.load();
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
    c.read(routerProvider).go('/doctor/patients/$demoPatientId/ai');
    await _settle(t);
    await t.tap(find.text(demoQuestions.first));
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.textContaining('7.2%'), findsWidgets);
  }, skip: skip);

  testWidgets('scan: sample picture -> scanner animation -> static data -> confirm', (t) async {
    final c = await _boot(t, 'demo-patient');
    c.read(routerProvider).go('/patient/scan');
    await _settle(t);
    expect(find.text('Try with a sample lab report'), findsOneWidget);
    await t.tap(find.text('Try with a sample lab report'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    // the scanner animation is on screen while "reading"
    expect(find.text('Scanning'), findsOneWidget);
    expect(find.text('Reading the text'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    // let the steps finish, then it hands over to the review screen
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(t.takeException(), isNull);
    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Read from your picture'), findsOneWidget);
    expect(find.textContaining('need your check'), findsOneWidget);
    expect(find.text('LDL cholesterol'), findsWidgets);
    // confirm -> it lands in her history
    final confirm = find.text('Confirm & save as verified');
    await t.ensureVisible(confirm);
    await t.tap(confirm);
    await _settle(t);
    expect(t.takeException(), isNull);
    final s = await DemoState.load();
    expect(s.extra.length, 1);
    expect(s.extra.first['verified'], isTrue);
    // let any in-flight fake-network timers finish before the test ends
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('patient chat: tap a question, the assistant types a grounded answer', (t) async {
    await _boot(t, 'demo-patient');
    await _settle(t);
    await t.tap(find.text('What does my sugar report mean?').first);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(t.takeException(), isNull);
    expect(find.text('Your health assistant'), findsOneWidget);
    expect(find.textContaining('8.6%'), findsWidgets);
    // keep chatting from the suggestions that remain
    await t.tap(find.text('What can I eat?').last);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('low-sugar diet'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('patient chat is reachable from every tab (Ask AI button)', (t) async {
    final c = await _boot(t, 'demo-patient');
    c.read(routerProvider).go('/patient/records');
    await _settle(t);
    expect(find.text('Ask AI'), findsOneWidget);
    await t.tap(find.text('Ask AI'));
    await _settle(t);
    expect(find.text('Your health assistant'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('doctor dashboard: AI brief + assistant that answers about the day', (t) async {
    final c = await _boot(t, 'demo-doctor');
    final s = await DemoState.load();
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
    c.read(routerProvider).go('/doctor');
    await _settle(t);
    expect(find.text('Your day at a glance'), findsOneWidget);
    expect(find.text('AI clinical assistant'), findsOneWidget);
    await t.tap(find.text('Who needs my attention today?'));
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(t.takeException(), isNull);
    expect(find.textContaining('HbA1c has risen at every test'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('doctor patient view: chat about this patient with source chips', (t) async {
    final c = await _boot(t, 'demo-doctor');
    final s = await DemoState.load();
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
    c.read(routerProvider).go('/doctor/patients/$demoPatientId/records');
    await _settle(t);
    expect(find.text('Ask about Ayesha'), findsOneWidget);
    await t.tap(find.text('Any documented drug allergy?').first);
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(t.takeException(), isNull);
    expect(find.textContaining('penicillin allergy is documented'), findsWidgets);
    expect(find.textContaining('Source'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('emergency access: dialog -> red critical-only screen', (t) async {
    await _boot(t, 'demo-doctor');
    await _settle(t);
    await t.tap(find.text('Emergency access'));
    await _settle(t);
    expect(find.text('Reason (required)'), findsOneWidget);
    // no reason -> a clear message, nothing happens
    await t.enterText(find.widgetWithText(TextField, 'Patient MediCard code'), demoCodeSpaced);
    await t.tap(find.text('Open emergency access'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('A reason is required'), findsOneWidget);
    await t.tap(find.text('Patient unconscious — cannot consent'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Open emergency access'));
    for (var i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(t.takeException(), isNull);
    expect(find.text('Ayesha Khan'), findsWidgets);
    expect(find.textContaining('CRITICAL INFORMATION ONLY'), findsOneWidget);
    expect(find.text('Penicillin'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);
}
