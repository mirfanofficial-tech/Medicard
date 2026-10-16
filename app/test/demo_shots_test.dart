// Visual QA helper: renders the key demo screens to PNGs in build/shots/.
//   flutter test test/demo_shots_test.dart --dart-define=DEMO=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

final _key = GlobalKey();

Future<void> _shoot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/shots/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<ProviderContainer> _boot(WidgetTester t, String? token, Size size, {bool granted = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  if (granted) {
    final s = await DemoState.load();
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
  }
  final c = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(_Store(token))]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: RepaintBoundary(key: _key, child: const MediCardApp()),
  ));
  await t.pump(const Duration(milliseconds: 600));
  return c;
}

Future<void> _wait(WidgetTester t, [int ms = 3000]) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  const skip = !Env.demo;
  setUpAll(loadRealFonts);
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await DemoState.reset();
  });

  testWidgets('shots: patient', (t) async {
    final c = await _boot(t, 'demo-patient', const Size(430, 2300));
    await _wait(t);
    await _shoot(t, 'p1_home');
    await t.tap(find.text('What does my sugar report mean?').first);
    await _wait(t, 9000);
    await _shoot(t, 'p2_chat');
    t.view.physicalSize = const Size(430, 1000);
    c.read(routerProvider).go('/patient/care-plan');
    await _wait(t);
    await _shoot(t, 'p3_careplan');
    t.view.physicalSize = const Size(430, 900);
    c.read(routerProvider).go('/patient/records');
    await _wait(t);
    await _shoot(t, 'p4_records');
    c.read(routerProvider).go('/patient/sharing');
    await _wait(t);
    await _shoot(t, 'p5_sharing');
    c.read(routerProvider).go('/patient/scan');
    await _wait(t);
    await _shoot(t, 'p6_scan');
    await t.tap(find.text('Try with a sample lab report'));
    await _wait(t, 3200);
    await _shoot(t, 'p7_scanning');
    await _wait(t, 4500);
    await _shoot(t, 'p8_review');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('shots: doctor', (t) async {
    final c = await _boot(t, 'demo-doctor', const Size(1440, 1500));
    await _wait(t);
    await _shoot(t, 'd1_dashboard');
    c.read(routerProvider).go('/doctor/patients/$demoPatientId/records');
    t.view.physicalSize = const Size(1440, 2000);
    await _wait(t);
    await _shoot(t, 'd2_patient');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  const patientRoutes = {
    'a1_notifications': '/patient/notifications',
    'a2_medications': '/patient/health/medications',
    'a3_allergies': '/patient/health/allergies',
    'a4_personal': '/patient/profile/personal',
    'a5_settings': '/patient/profile/settings',
    'a6_help': '/patient/profile/help',
    'a7_requests': '/patient/sharing/requests',
    'a8_activity': '/patient/sharing/activity',
    'a9_record': '/patient/records/r11',
    'a10_profile': '/patient/profile',
  };
  testWidgets('shots: patient extra', (t) async {
    final c = await _boot(t, 'demo-patient', const Size(430, 900));
    await _wait(t, 1500);
    for (final e in patientRoutes.entries) {
      c.read(routerProvider).go(e.value);
      await _wait(t, 2500);
      await _shoot(t, e.key);
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  const doctorRoutes = {
    'b1_request': '/doctor/request',
    'b2_record': '/doctor/patients/$demoPatientId/records/r10',
    'b3_critical': '/doctor/patients/$demoPatientId/critical',
    'b4_ai': '/doctor/patients/$demoPatientId/ai',
    'b5_prescribe': '/doctor/patients/$demoPatientId/prescribe',
  };
  testWidgets('shots: doctor extra', (t) async {
    final c = await _boot(t, 'demo-doctor', const Size(1280, 1100));
    await _wait(t, 1500);
    for (final e in doctorRoutes.entries) {
      c.read(routerProvider).go(e.value);
      await _wait(t, 2500);
      await _shoot(t, e.key);
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('shots: entry screens', (t) async {
    final c = await _boot(t, null, const Size(1440, 900), granted: false);
    await _wait(t, 1500);
    await _shoot(t, 'e1_landing_desktop');
    t.view.physicalSize = const Size(430, 900);
    await _wait(t, 800);
    await _shoot(t, 'e2_landing_phone');
    c.read(routerProvider).go('/patient/auth');
    await _wait(t, 1200);
    await _shoot(t, 'e3_patient_auth');
    c.read(routerProvider).go('/doctor/auth');
    await _wait(t, 1200);
    await _shoot(t, 'e4_doctor_auth');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);

  testWidgets('shots: emergency + record', (t) async {
    final c = await _boot(t, 'demo-doctor', const Size(1100, 1000));
    final s = await DemoState.load();
    s.data['emergency'] = {'at': DateTime.now().toIso8601String(), 'reason': 'Unconscious in ER'};
    s.status = 'none';
    await s.save();
    c.read(routerProvider).go('/doctor/patients/$demoPatientId/critical');
    await _wait(t, 2500);
    await _shoot(t, 'f1_critical');
    s.status = 'approved';
    s.data['granted_at'] = DateTime.now().toIso8601String();
    await s.save();
    c.read(routerProvider).go('/doctor/patients/$demoPatientId/records/r10');
    await _wait(t, 2500);
    await _shoot(t, 'f2_record');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: skip);
}
