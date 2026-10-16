import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicard/src/demo/demo_backend.dart';
import 'package:medicard/src/demo/demo_data.dart';
import 'package:medicard/src/demo/demo_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Dio _client(String role) => Dio(BaseOptions(
      baseUrl: 'http://demo',
      headers: {'Authorization': 'Bearer demo-$role'},
      validateStatus: (_) => true,
    ))
      ..httpClientAdapter = DemoAdapter();

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoState.reset();
  });

  test('the whole MVP story runs from static data', () async {
    final doctor = _client('doctor');
    final patient = _client('patient');

    // 1. sign in
    final login = await doctor.post('/auth/doctor/login',
        data: {'email': demoDoctorEmail, 'password': 'x'});
    expect(login.statusCode, 200);
    expect((await patient.get('/auth/me')).data['profile']['name'], 'Ayesha Khan');

    // 2. no access before consent
    final locked = await doctor.get('/doctor/patients/$demoPatientId/overview');
    expect(locked.statusCode, 403);
    var dash = (await doctor.get('/doctor/dashboard')).data as Map;
    expect(dash['stats']['active_access'], 0);
    final schedule = dash['schedule'] as List;
    expect(schedule.length, greaterThan(4));
    expect(schedule.where((p) => p['active'] == true).length, 1); // only Ayesha is active

    // 3. a wrong code explains itself
    final bad = await doctor.post('/doctor/access-requests', data: {'medicard_code': 'ZZZZ'});
    expect(bad.statusCode, 404);
    expect('${bad.data['detail']}', contains(demoCodeSpaced));

    // 4. doctor enters Ayesha's code -> patient sees the request
    final req = await doctor.post('/doctor/access-requests', data: {'medicard_code': '46a9 ft39'});
    expect(req.statusCode, 201);
    final pending = (await patient.get('/patient/access-requests')).data as List;
    expect(pending.single['doctor_name'], 'Sara Ahmed');
    expect((await patient.get('/patient/home')).data['pending_requests'], 1);

    // 5. patient says yes -> doctor can see everything
    final ok = await patient.post('/patient/access-requests/req-ayesha/approve');
    expect(ok.statusCode, 200);
    final ov = (await doctor.get('/doctor/patients/$demoPatientId/overview')).data as Map;
    expect(ov['name'], 'Ayesha Khan');
    expect(ov['counts']['documents'], 11);
    expect((ov['trends'] as List).first['name'], 'HbA1c');
    expect((ov['history_alerts'] as List).any((a) => a['title'] == 'Penicillin'), isTrue);
    expect((ov['history_alerts'] as List).any((a) => a['title'] == 'Ibuprofen'), isTrue);
    dash = (await doctor.get('/doctor/dashboard')).data as Map;
    expect(dash['stats']['active_access'], 1);
    expect((dash['active'] as List).single['alerts'], isNotEmpty);

    // 6. static AI: summary + every suggested question has a real answer
    final ai = (await doctor.get('/doctor/patients/$demoPatientId/ai-summary')).data as Map;
    expect((ai['flags'] as List).length, 3);
    for (final q in demoQuestions) {
      final a = (await doctor.post('/doctor/patients/$demoPatientId/ai-ask', data: {'question': q}))
          .data as Map;
      expect(a['answered_from_records'], isTrue, reason: q);
      expect((a['answer'] as String).length, greaterThan(40), reason: q);
    }

    // 7. voice dictation -> structured draft; checks flag ibuprofen
    final v = (await doctor.post('/doctor/voice/parse', data: {'text': demoDictation})).data as Map;
    expect((v['medications'] as List).first['name'], 'Metformin');
    final chk = (await doctor.post('/doctor/patients/$demoPatientId/prescribe/check', data: {
      'medications': [
        {'name': 'Ibuprofen', 'dose': '400 mg'},
        {'name': 'Amoxicillin'},
      ],
    })).data['checks'] as List;
    expect(chk.any((c) => c['kind'] == 'allergy' && c['severity'] == 'urgent'), isTrue);
    expect(chk.any((c) => c['kind'] == 'reaction'), isTrue);

    // 8. prescribe -> lands on the patient's side
    final save = await doctor.post('/doctor/patients/$demoPatientId/prescribe', data: {
      'medications': v['medications'],
      'advice': v['advice'],
    });
    expect(save.statusCode, 201);
    expect(save.data['care_plan_created'], isTrue);
    final plan = (await patient.get('/patient/care-plan')).data as Map;
    expect(plan['diet']['note'], 'Low-sugar diet');
    expect(plan['issued_by'], 'Dr Sara Ahmed');
    expect(((await patient.get('/records')).data as List).first['record_id'], isNotEmpty);

    // 9. patient daily ticks persist
    final home = (await patient.get('/patient/home')).data as Map;
    final next = home['next_medicine'] as Map?;
    if (next != null) {
      final t = (await patient.post('/patient/care/log',
              data: {'item_key': next['key'], 'done': true}))
          .data as Map;
      expect(t['done'], greaterThan(home['today']['done'] as int));
    }
    final a = (await patient.post('/patient/ask', data: {'question': 'What does my sugar report mean?'}))
        .data as Map;
    expect(a['answered_from_records'], isTrue);
    expect('${a['answer']}', contains('8.6'));

    // 10. ending access locks the doctor out again
    await doctor.post('/doctor/grants/grant-1/end');
    expect((await doctor.get('/doctor/patients/$demoPatientId/overview')).statusCode, 403);
  });

  test('scan -> review -> confirm adds a verified record', () async {
    final patient = _client('patient');
    final before = ((await patient.get('/records')).data as List).length;
    final up = (await patient.post('/records/upload', data: {})).data as Map;
    final id = up['record_id'] as String;
    final ex = (await patient.post('/records/$id/extract')).data as Map;
    expect((ex['extraction']['confidence_by_field'] as Map).values.any((v) => (v as num) < 0.7),
        isTrue);
    final conf = await patient.post('/records/$id/confirm',
        data: {'type': 'lab', 'data': ex['draft'], 'provider': 'Chughtai Lab'});
    expect(conf.statusCode, 200);
    expect(((await patient.get('/records')).data as List).length, before + 1);
    // the app opens the record under the id it uploaded
    expect((await patient.get('/records/$id')).statusCode, 200);
  });

  test('emergency access: reason required, critical-only, full record stays closed, patient told', () async {
    final doctor = _client('doctor');
    final patient = _client('patient');

    final noReason = await doctor.post('/doctor/break-glass', data: {'medicard_code': demoCode, 'reason': ''});
    expect(noReason.statusCode, 422);
    final wrong = await doctor.post('/doctor/break-glass', data: {'medicard_code': 'NOPE12', 'reason': 'Unconscious'});
    expect(wrong.statusCode, 404);

    final ok = await doctor.post('/doctor/break-glass',
        data: {'medicard_code': demoCode, 'reason': 'Unconscious in ER'});
    expect(ok.statusCode, 201);
    expect((ok.data['allergies'] as List).contains('Penicillin'), isTrue);

    // critical view works, the full record does not
    expect((await doctor.get('/doctor/patients/$demoPatientId/critical')).statusCode, 200);
    expect((await doctor.get('/doctor/patients/$demoPatientId/overview')).statusCode, 403);
    final grants = (await doctor.get('/doctor/grants')).data as List;
    expect(grants.single['scope'], 'critical');
    expect(grants.single['source'], 'break_glass');
    final dash = (await doctor.get('/doctor/dashboard')).data as Map;
    expect((dash['active'] as List).single['scope'], 'critical');

    // the patient is told, with the reason
    final hist = (await patient.get('/patient/access-history')).data as List;
    expect(hist.first['action'], 'break_glass');
    expect(hist.first['reason'], 'Unconscious in ER');

    await doctor.post('/doctor/grants/grant-em/end');
    expect((await doctor.get('/doctor/patients/$demoPatientId/critical')).statusCode, 403);
  });
}
