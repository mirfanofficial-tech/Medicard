// Walks every screen of the demo on a phone and a desktop size and fails on any
// exception / layout overflow.
//   flutter test test/demo_smoke_test.dart --dart-define=DEMO=true
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

const _patientRoutes = [
  '/patient',
  '/patient/records',
  '/patient/scan',
  '/patient/sharing',
  '/patient/profile',
  '/patient/care-plan',
  '/patient/notifications',
  '/patient/health/medications',
  '/patient/health/allergies',
  '/patient/profile/personal',
  '/patient/profile/settings',
  '/patient/profile/help',
  '/patient/sharing/requests',
  '/patient/sharing/activity',
  '/patient/records/r11',
  '/patient/records/r10',
];

const _doctorRoutes = [
  '/doctor',
  '/doctor/request',
  '/doctor/patients/$demoPatientId/records',
  '/doctor/patients/$demoPatientId/records/r11',
  '/doctor/patients/$demoPatientId/records/r10',
  '/doctor/patients/$demoPatientId/critical',
  '/doctor/patients/$demoPatientId/ai',
  '/doctor/patients/$demoPatientId/prescribe',
];

void main() {
  const skip = !Env.demo;

  setUpAll(loadRealFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoState.reset();
  });

  Future<ProviderContainer> boot(WidgetTester t, String token, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = await DemoState.load();
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
    final c = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(_Store(token))]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MediCardApp()));
    await t.pump(const Duration(milliseconds: 600));
    return c;
  }

  Future<void> visit(WidgetTester t, ProviderContainer c, String route) async {
    c.read(routerProvider).go(route);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    final e = t.takeException();
    expect(e, isNull, reason: 'on $route');
  }

  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('every patient screen renders at ${size.width.toInt()}px', (t) async {
      final c = await boot(t, 'demo-patient', size);
      for (final r in _patientRoutes) {
        await visit(t, c, r);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    }, skip: skip);

    testWidgets('every doctor screen renders at ${size.width.toInt()}px', (t) async {
      final c = await boot(t, 'demo-doctor', size);
      for (final r in _doctorRoutes) {
        await visit(t, c, r);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    }, skip: skip);
  }
}
