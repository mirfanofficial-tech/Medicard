import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'demo_data.dart';
import 'demo_state.dart';

class _Res {
  _Res(this.status, [this.body]);
  final int status;
  final Object? body;
}

_Res _err(int status, String detail) => _Res(status, {'detail': detail});

/// A Dio adapter that answers every API call from static data. With `DEMO=true`
/// the whole app runs on this — no server, no network.
class DemoAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 160)); // feels like a network
    // One request at a time: load -> answer -> save, so two quick calls can't overwrite
    // each other's changes to the shared demo state.
    final res = await _serial(() async {
      final st = await DemoState.load();
      final before = jsonEncode(st.data);
      final r = await _route(options, st);
      if (jsonEncode(st.data) != before) await st.save();
      return r;
    });
    final text = res.body == null ? '' : jsonEncode(res.body);
    return ResponseBody.fromString(
      text,
      res.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await job());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  // ------------------------------------------------------------------ routing

  Future<_Res> _route(RequestOptions o, DemoState st) async {
    final method = o.method.toUpperCase();
    final path = o.path.split('?').first;
    final auth = '${o.headers['Authorization'] ?? ''}';
    final isDoctor = auth.contains('demo-doctor');
    final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};

    // ---- auth ----
    if (path == '/auth/patient/otp/request') return _Res(200, {'dev_code': '123456'});
    if (path == '/auth/patient/otp/verify') {
      return _Res(200, {
        'tokens': _tokens('demo-patient'),
        'patient_id': demoPatientId,
        'medicard_code': demoCode,
        'is_new': false,
      });
    }
    if (path == '/auth/doctor/login') {
      if ('${body['email']}'.toLowerCase() != demoDoctorEmail) {
        return _err(401, 'Demo: sign in as $demoDoctorEmail');
      }
      return _Res(200, {'tokens': _tokens('demo-doctor'), 'doctor_id': demoDoctorId, 'status': 'active'});
    }
    if (path == '/auth/doctor/register') {
      return _Res(201, {'tokens': _tokens('demo-doctor'), 'doctor_id': demoDoctorId, 'status': 'active'});
    }
    if (path == '/auth/refresh') return _Res(200, _tokens(isDoctor ? 'demo-doctor' : 'demo-patient'));
    if (path == '/auth/me') {
      if (!auth.contains('demo-')) return _err(401, 'Not signed in');
      return _Res(200, isDoctor ? _meDoctor() : _mePatient());
    }

    final recs = _records(st);
    final h = History(recs);

    // ---- patient ----
    if (path.startsWith('/patient/') || path.startsWith('/records')) {
      final r = _patientRoute(method, path, body, st, h, recs);
      if (r != null) return r;
    }

    // ---- doctor ----
    if (path.startsWith('/doctor/')) {
      final r = _doctorRoute(method, path, body, st, h, recs);
      if (r != null) return r;
    }

    return _err(404, 'Not part of the demo: $method $path');
  }

  Map<String, dynamic> _tokens(String t) => {'access_token': t, 'refresh_token': '$t-refresh'};

  Map<String, dynamic> _mePatient() => {
        'user_id': 'u-ayesha',
        'role': 'patient',
        'profile': {
          'patient_id': demoPatientId,
          'name': 'Ayesha Khan',
          'medicard_code': demoCode,
          'phone': demoPhone,
        },
      };

  Map<String, dynamic> _meDoctor() => {
        'user_id': 'u-sara',
        'role': 'doctor',
        'profile': {
          'doctor_id': demoDoctorId,
          'name': 'Sara Ahmed',
          'status': 'active',
          'specialty': 'Internal Medicine',
          'hospital': 'City Hospital, Lahore',
          'licence_no': 'PMDC-DEMO-4471',
        },
      };

  // ------------------------------------------------------------------ records

  List<Map<String, dynamic>> _records(DemoState st) {
    final out = [...baseRecords(), ...st.extra];
    final rx = st.rx;
    if (rx != null) {
      out.add({
        'record_id': 'r-rx-new',
        'type': 'prescription',
        'doc_date': rx['date'],
        'provider': 'Dr Sara Ahmed · City Hospital',
        'verified': true,
        'sensitive': false,
        'created_at': '${rx['date']}T09:00:00',
        'data': {
          'diagnoses': <String>[],
          'medications': (rx['meds'] as List)
              .map((m) => {
                    'name': (m as Map)['name'],
                    'dose': m['dose'],
                    'route': 'oral',
                    'freq': m['freq'],
                    'days': m['days'],
                  })
              .toList(),
          'lab_results': <Map<String, dynamic>>[],
          'allergies': <String>[],
          'reactions': <Map<String, dynamic>>[],
          'stopped': <Map<String, dynamic>>[],
          'notes': rx['notes'],
        },
      });
    }
    return out;
  }

  Map<String, dynamic> _summaryRow(Map<String, dynamic> r) => {
        'record_id': r['record_id'],
        'type': r['type'],
        'doc_date': r['doc_date'],
        'provider': r['provider'],
        'verified': r['verified'],
        'sensitive': r['sensitive'],
        'created_at': r['created_at'],
      };

  Map<String, dynamic> _detail(Map<String, dynamic> r) {
    final d = dataOf(r);
    return {
      ..._summaryRow(r),
      'data': {
        'diagnoses': d['diagnoses'],
        'medications': d['medications'],
        'lab_results': d['lab_results'],
        'allergies': d['allergies'],
        'notes': d['notes'],
      },
      'source_url': null,
      'extraction': null,
    };
  }

  // ------------------------------------------------------------- care helpers

  static const _prn = ['prn', 'when needed', 'as needed'];

  List<String> _slots(String? freq) {
    final f = (freq ?? '').toLowerCase();
    if (_prn.any(f.contains)) return [];
    if (f.contains('twice') || f.contains('bd')) return ['08:00', '20:00'];
    if (f.contains('night') || f.contains('bedtime')) return ['20:00'];
    return ['08:00'];
  }

  String _hhmm(String t) {
    final hr = int.parse(t.substring(0, 2));
    final m = t.substring(3);
    return '${(hr % 12) == 0 ? 12 : hr % 12}:$m ${hr < 12 ? 'am' : 'pm'}';
  }

  String _word(String t) {
    final hr = int.parse(t.substring(0, 2));
    return hr < 12 ? 'Morning' : hr < 17 ? 'Afternoon' : 'Night';
  }

  Map<String, dynamic> _plan(DemoState st) {
    final rx = st.rx;
    final adv = rx == null ? null : (rx['advice'] as Map?)?.cast<String, dynamic>();
    final issued = rx != null && adv != null ? DateTime.now() : daysAgo(9);
    final diet = adv?['diet'] as Map? ??
        {
          'note': 'Low-sugar diet',
          'more': ['Daal and sabzi', 'Salad', 'Daliya', 'Plain yogurt'],
          'less': ['Sugar in chai', 'Mithai', 'Fried food', 'Cold drinks'],
        };
    final activity = ((adv?['activity'] as List?) ?? ['Walk 20 minutes']).map((e) => '$e').toList();
    final followDays = (adv?['follow_up_days'] as int?) ?? 14;
    final base = DateTime(issued.year, issued.month, issued.day);
    final tests = adv == null
        ? [
            {'name': 'Fasting sugar test', 'due': daysAhead(6)},
            {'name': 'HbA1c test', 'due': daysAhead(33)},
          ]
        : ((adv['tests'] as List?) ?? [])
            .map((t) => {
                  'name': '${(t as Map)['name']}',
                  'due': base.add(Duration(days: (t['in_days'] as int?) ?? 0)),
                })
            .toList();
    return {
      'issued': issued,
      'diet': diet,
      'activity': activity,
      'tests': tests,
      'follow_up': adv == null ? daysAhead(14) : base.add(Duration(days: followDays)),
    };
  }

  Set<String> _doneToday(DemoState st) {
    final key = ymd(DateTime.now());
    final ticks = Map<String, dynamic>.from(st.data['ticks'] as Map? ?? {});
    if (!ticks.containsKey(key)) {
      st.setTick(key, 'med:metformin:08:00', true); // morning dose already taken
      st.save();
    }
    return st.ticksFor(key);
  }

  List<Map<String, dynamic>> _todayItems(DemoState st, History h) {
    final plan = _plan(st);
    final done = _doneToday(st);
    final items = <Map<String, dynamic>>[];
    for (final m in h.meds) {
      for (final t in _slots('${m['freq']}')) {
        final key = 'med:${norm('${m['name']}').replaceAll(' ', '-')}:$t';
        final title = [m['name'], m['dose']].where((e) => e != null && '$e'.isNotEmpty).join(' ');
        items.add({
          'key': key,
          'kind': 'medicine',
          'title': title,
          'sub': '${_word(t)} · ${_hhmm(t)}',
          'time': t,
          'done': done.contains(key),
        });
      }
    }
    final dietNote = (plan['diet'] as Map)['note'];
    if (dietNote != null) {
      items.add({
        'key': 'diet:0',
        'kind': 'diet',
        'title': '$dietNote',
        'sub': 'All day',
        'time': '12:00',
        'done': done.contains('diet:0'),
      });
    }
    final acts = plan['activity'] as List<String>;
    for (var i = 0; i < acts.length; i++) {
      items.add({
        'key': 'act:$i',
        'kind': 'activity',
        'title': acts[i],
        'sub': 'After dinner',
        'time': '21:00',
        'done': done.contains('act:$i'),
      });
    }
    items.sort((a, b) => '${a['time']}${a['title']}'.compareTo('${b['time']}${b['title']}'));
    return items;
  }

  Map<String, dynamic> _todayView(DemoState st, History h) {
    final items = _todayItems(st, h);
    return {
      'done': items.where((i) => i['done'] == true).length,
      'total': items.length,
      'items': items,
    };
  }

  Map<String, dynamic>? _nextMedicine(List<Map<String, dynamic>> items) {
    final pending = items.where((i) => i['kind'] == 'medicine' && i['done'] != true).toList();
    if (pending.isEmpty) return null;
    final now = DateTime.now();
    final nowM = now.hour * 60 + now.minute;
    int mins(Map<String, dynamic> i) {
      final t = '${i['time']}';
      return int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3)) - nowM;
    }

    final upcoming = pending.where((i) => mins(i) >= -30).toList();
    final pick = upcoming.isNotEmpty
        ? (upcoming..sort((a, b) => mins(a).compareTo(mins(b)))).first
        : (pending..sort((a, b) => mins(b).compareTo(mins(a)))).first;
    return {
      'key': pick['key'],
      'name': pick['title'],
      'at': _hhmm('${pick['time']}'),
      'in_minutes': mins(pick),
    };
  }

  Map<String, dynamic> _followUp(DemoState st) {
    final d = _plan(st)['follow_up'] as DateTime;
    return {'date': ymd(d), 'when': wdDMon(d), 'with_doctor': 'Dr Sara Ahmed'};
  }

  Map<String, dynamic> _carePlan(DemoState st, History h) {
    final plan = _plan(st);
    final issued = plan['issued'] as DateTime;
    final days = DateTime.now().difference(issued).inDays.clamp(0, 999);
    final diet = Map<String, dynamic>.from(plan['diet'] as Map);
    final events = <Map<String, dynamic>>[
      for (final t in plan['tests'] as List)
        {
          'title': (t as Map)['name'],
          'when': wdDMon(t['due'] as DateTime),
          'date': ymd(t['due'] as DateTime),
          'kind': 'test',
        },
      {
        'title': 'Doctor follow-up',
        'when': wdDMon(plan['follow_up'] as DateTime),
        'date': ymd(plan['follow_up'] as DateTime),
        'kind': 'visit',
      },
    ]..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    return {
      'has_plan': true,
      'issued_by': 'Dr Sara Ahmed',
      'issued_on': ymd(issued),
      'week': (days ~/ 7 + 1).clamp(1, 6),
      'of': 6,
      'percent': (days / 42 * 100).round().clamp(0, 100),
      'today': _todayView(st, h),
      'diet': {'note': diet['note'], 'more': diet['more'] ?? [], 'less': diet['less'] ?? []},
      'activity': plan['activity'],
      'events': events,
      'follow_up': _followUp(st),
      'disclaimer': "This plan follows your doctor's advice. If you feel very unwell, contact "
          'your doctor or go to the nearest hospital.',
    };
  }

  String _friendly(String name) {
    final n = name.toLowerCase();
    if (n.contains('hba1c') || n.contains('glucose') || n.contains('sugar')) return 'sugar';
    if (n.contains('cholesterol') || n.contains('ldl') || n.contains('lipid')) return 'cholesterol';
    if (n.contains('creatinine')) return 'kidney test';
    return name;
  }

  List<Map<String, dynamic>> _reports(History h, int limit) {
    final out = <Map<String, dynamic>>[];
    for (final r in h.ofType('lab').take(limit)) {
      final labs = (dataOf(r)['lab_results'] as List).cast<Map>();
      final flags = labs.map((x) => flagOf(x['value'], x['ref_range'] as String?)).toList();
      final level = flags.contains('high')
          ? 'high'
          : flags.contains('low')
              ? 'low'
              : flags.contains('normal')
                  ? 'normal'
                  : 'unknown';
      final first = '${labs.first['name']}';
      final f = _friendly(first);
      final title = first.toLowerCase().contains('hba1c')
          ? 'Sugar test (HbA1c)'
          : '${f[0].toUpperCase()}${f.substring(1)} test';
      out.add({
        'record_id': r['record_id'],
        'title': title,
        'sub': '${dMon(DateTime.parse('${r['doc_date']}'))} · ${'${r['provider']}'.split(' · ').first}',
        'verdict': {'high': 'High', 'low': 'Low', 'normal': 'All normal', 'unknown': 'See report'}[level],
        'level': level,
      });
    }
    return out;
  }

  // ------------------------------------------------------------------ patient

  _Res? _patientRoute(
    String method,
    String path,
    Map<String, dynamic> body,
    DemoState st,
    History h,
    List<Map<String, dynamic>> recs,
  ) {
    switch ('$method $path') {
      case 'GET /patient/home':
        final today = _todayView(st, h);
        final hba = h.series['HbA1c'] ?? [];
        final trend = hba.length >= 2 ? hba.sublist(hba.length >= 4 ? hba.length - 4 : 0) : [];
        return _Res(200, {
          'name': 'Ayesha Khan',
          'next_medicine': _nextMedicine((today['items'] as List).cast<Map<String, dynamic>>()),
          'today': today,
          'summary': {
            'text': 'Your sugar has gone up in your last ${hba.length} tests. Keep taking your '
                'medicines every day. See your doctor on ${dMon(_plan(st)['follow_up'] as DateTime)}.',
            'trend': [
              for (final p in trend)
                {'label': monthName(DateTime.parse('${p['date']}')), 'value': p['value']},
            ],
            'unit': '%',
            'note': 'Explained from your own records. It is not a diagnosis.',
          },
          'reports': _reports(h, 2),
          'more_reports': h.ofType('lab').length > 2,
          'tips': [
            {'emoji': '👩‍⚕️', 'title': (_plan(st)['activity'] as List).first, 'sub': "Your doctor's advice", 'from_doctor': true},
            {'emoji': '🍵', 'title': 'Try chai with less sugar', 'sub': 'One spoon less each day', 'from_doctor': false},
            {'emoji': '💧', 'title': 'Drink 8 glasses of water', 'sub': 'Keep a bottle with you', 'from_doctor': false},
          ],
          'asks': [
            'What does my sugar report mean?',
            'What is each medicine for?',
            'What can I eat?',
            'When is my next test?',
          ],
          'follow_up': _followUp(st),
          'pending_requests': st.pending ? 1 : 0,
          'numbers': _numbers(h),
          'emergency': {
            'blood_group': 'B+',
            'allergies': h.allergies,
            'conditions': h.conditions,
            'medicines': [for (final m in h.meds) '${m['name']} ${m['dose'] ?? ''}'.trim()],
          },
        });
      case 'GET /patient/care-plan':
        return _Res(200, _carePlan(st, h));
      case 'POST /patient/care/log':
        st.setTick(ymd(DateTime.now()), '${body['item_key']}', body['done'] != false);
        st.save();
        return _Res(200, _todayView(st, h));
      case 'POST /patient/ask':
        return _Res(200, demoPatientAnswer('${body['question']}'));
      case 'GET /patient/me':
        return _Res(200, {
          'patient_id': demoPatientId,
          'name': 'Ayesha Khan',
          'medicard_code': demoCode,
          'phone': demoPhone,
          'dob': '1979-04-12',
          'gender': 'Female',
          'blood_group': 'B+',
          'address': '12 Jail Road, Lahore',
        });
      case 'PATCH /patient/me':
        return _Res(200, {
          'patient_id': demoPatientId,
          'name': body['name'] ?? 'Ayesha Khan',
          'medicard_code': demoCode,
          'phone': demoPhone,
          'dob': body['dob'] ?? '1979-04-12',
          'gender': body['gender'] ?? 'Female',
          'blood_group': body['blood_group'] ?? 'B+',
          'address': body['address'] ?? '12 Jail Road, Lahore',
        });
      case 'GET /patient/overview':
        final recent = recs.reversed.toList()
          ..sort((a, b) => '${b['doc_date']}'.compareTo('${a['doc_date']}'));
        return _Res(200, {
          'name': 'Ayesha Khan',
          'records': recs.length,
          'lab_reports': h.ofType('lab').length,
          'prescriptions': h.ofType('prescription').length,
          'imaging': h.ofType('imaging').length,
          'medications': h.meds.length,
          'allergies': h.allergies.length,
          'recent': [
            for (final r in recent.take(5))
              {
                'record_id': r['record_id'],
                'type': r['type'],
                'provider': r['provider'],
                'doc_date': r['doc_date'],
                'verified': true,
                'created_at': r['created_at'],
              },
          ],
        });
      case 'GET /patient/medications':
        return _Res(200, h.meds);
      case 'GET /patient/allergies':
        return _Res(200, [
          for (final a in h.allergies)
            {
              'name': a,
              'source_record_ids': [
                for (final r in recs)
                  if ((dataOf(r)['allergies'] as List).contains(a)) r['record_id'],
              ],
            },
        ]);
      case 'GET /patient/ai-summary':
        final s = demoAiSummary();
        return _Res(200, {
          ...s,
          'summary': 'Your sugar (HbA1c) has gone up in your last 4 tests, from 7.2% to 8.6%. '
              'Your blood pressure and cholesterol are close to target. Keep taking your medicines, '
              'follow the diet and walk daily.',
        });
      case 'GET /patient/access-requests':
        return _Res(200, st.pending
            ? [
                {
                  'request_id': 'req-ayesha',
                  'doctor_name': 'Sara Ahmed',
                  'hospital': 'City Hospital, Lahore',
                  'specialty': 'Internal Medicine',
                  'for_patient': 'Ayesha Khan',
                  'created_at': (st.requestedAt ?? DateTime.now()).toUtc().toIso8601String(),
                }
              ]
            : []);
      case 'POST /patient/access-requests/req-ayesha/approve':
        st.status = 'approved';
        st.data['granted_at'] = DateTime.now().toIso8601String();
        st.addLog('grant', 'Patient approved access', scope: 'full');
        st.save();
        return _Res(200, _grantView(st));
      case 'POST /patient/access-requests/req-ayesha/deny':
        st.status = 'denied';
        st.addLog('deny', 'Patient declined access');
        st.save();
        return _Res(204);
      case 'GET /patient/grants':
        return _Res(200, st.granted ? [_grantView(st)] : []);
      case 'POST /patient/grants/grant-1/revoke':
        st.status = 'none';
        st.addLog('revoke', 'Patient revoked access');
        st.save();
        return _Res(204);
      case 'GET /patient/access-history':
        return _Res(200, _accessHistory(st));
      case 'GET /records':
        return _Res(200, [for (final r in _sortedDesc(recs)) _summaryRow(r)]);
      case 'POST /records/upload':
        return _Res(201, {'record_id': 'r-scan-${st.extra.length + 1}', 'type': 'lab'});
    }

    final scan = RegExp(r'^/records/(r-scan-\d+)/(extract|confirm)$').firstMatch(path);
    if (scan != null && method == 'POST') {
      final id = scan.group(1)!;
      if (scan.group(2) == 'extract') {
        return _Res(200, {
          'record_id': id,
          'extraction': {
            'job_id': 'job-$id',
            'status': 'needs_review',
            'confidence_by_field': {
              'lab_results.0.name': 0.98,
              'lab_results.0.value': 0.62,
              'lab_results.1.value': 0.96,
              'lab_results.2.value': 0.55,
              'lab_results.3.value': 0.94,
              'lab_results.4.value': 0.97,
              'doc_date': 0.9,
            },
          },
          'draft': demoExtractionDraft(),
        });
      }
      final rec = {
        'record_id': id,
        'type': body['type'] ?? 'lab',
        'doc_date': body['doc_date'] ?? ymd(DateTime.now()),
        'provider': body['provider'] ?? 'Uploaded by you',
        'verified': true,
        'sensitive': false,
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          ...Map<String, dynamic>.from(body['data'] as Map? ?? demoExtractionDraft()),
          'reactions': <Map<String, dynamic>>[],
          'stopped': <Map<String, dynamic>>[],
        },
      };
      final extra = st.extra..removeWhere((r) => r['record_id'] == id)..add(rec);
      st.data['extra'] = extra;
      st.save();
      return _Res(200, _detail(rec));
    }

    final m = RegExp(r'^/records/([^/]+)(/sensitive)?$').firstMatch(path);
    if (m != null) {
      final rec = recs.where((r) => r['record_id'] == m.group(1)).firstOrNull;
      if (rec == null) return _err(404, 'Record not found');
      return _Res(200, _detail(rec));
    }
    return null;
  }

  /// "My numbers": the few results a patient should know, with an arrow and a plain goal.
  List<Map<String, dynamic>> _numbers(History h) {
    final series = h.series;
    Map<String, dynamic>? tile(String key, String label) {
      final pts = series[key];
      if (pts == null || pts.isEmpty) return null;
      final last = pts.last;
      final prev = pts.length > 1 ? pts[pts.length - 2]['value'] as double : null;
      final v = last['value'] as double;
      final ref = '${last['ref'] ?? ''}';
      return {
        'label': label,
        'value': v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
        'unit': '${last['unit'] ?? ''}',
        'status': flagOf(v, ref),
        'trend': prev == null ? 'flat' : v > prev ? 'up' : v < prev ? 'down' : 'flat',
        'goal': ref.startsWith('<') ? 'Goal: below ${ref.substring(1)}' : ref.isEmpty ? '' : 'Normal: $ref',
      };
    }

    return [
      tile('HbA1c', 'Sugar (HbA1c)'),
      tile('Fasting glucose', 'Fasting sugar'),
      tile('Systolic blood pressure', 'Blood pressure (top)'),
    ].whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _sortedDesc(List<Map<String, dynamic>> recs) {
    final out = [...recs];
    out.sort((a, b) => '${b['doc_date']}'.compareTo('${a['doc_date']}'));
    return out;
  }

  Map<String, dynamic> _grantView(DemoState st) => {
        'grant_id': 'grant-1',
        'doctor_name': 'Sara Ahmed',
        'hospital': 'City Hospital, Lahore',
        'scope': 'full',
        'source': 'consent',
        'granted_at': (st.grantedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'expires_at': (st.expiresAt ?? DateTime.now().add(const Duration(hours: 12)))
            .toUtc()
            .toIso8601String(),
        'ended_at': null,
      };

  List<Map<String, dynamic>> _accessHistory(DemoState st) {
    Map<String, dynamic> e(DateTime at, String action, {String scope = 'full', String? reason}) => {
          'at': at.toUtc().toIso8601String(),
          'action': action,
          'for_patient': 'Ayesha Khan',
          'scope': scope,
          'doctor_name': 'Sara Ahmed',
          'hospital': 'City Hospital, Lahore',
          'reason': reason,
        };
    final now = DateTime.now();
    return [
      for (final l in st.log)
        e(
          DateTime.tryParse('${l['at']}') ?? now,
          '${l['action']}',
          scope: '${l['scope'] ?? 'full'}',
          reason: l['action'] == 'break_glass'
              ? '${l['text']}'.replaceFirst('Emergency access: ', '')
              : null,
        ),
      e(now.subtract(const Duration(days: 4, hours: 3)), 'view'),
      e(now.subtract(const Duration(days: 40, hours: 2)), 'prescribe'),
      e(now.subtract(const Duration(days: 40, hours: 2)), 'view'),
      e(now.subtract(const Duration(days: 40, hours: 3)), 'grant'),
      e(now.subtract(const Duration(days: 110)), 'view'),
    ];
  }

  // ------------------------------------------------------------------- doctor

  _Res? _doctorRoute(
    String method,
    String path,
    Map<String, dynamic> body,
    DemoState st,
    History h,
    List<Map<String, dynamic>> recs,
  ) {
    final key = '$method $path';
    if (key == 'GET /doctor/dashboard') return _Res(200, _dashboard(st, h));
    if (key == 'GET /doctor/grants') {
      if (!st.granted && st.emergencyActive) {
        return _Res(200, [_emergencyGrant(st)]);
      }
      return _Res(200, st.granted
          ? [
              {
                'grant_id': 'grant-1',
                'patient_id': demoPatientId,
                'patient_name': 'Ayesha Khan',
                'scope': 'full',
                'source': 'consent',
                'granted_at': (st.grantedAt ?? DateTime.now()).toUtc().toIso8601String(),
                'expires_at': st.expiresAt!.toUtc().toIso8601String(),
              }
            ]
          : []);
    }
    if (key == 'GET /doctor/access-requests') return _Res(200, []);
    if (key == 'POST /doctor/access-requests') {
      final code = '${body['medicard_code']}'.replaceAll(' ', '').toUpperCase();
      if (code != demoCode) {
        return _err(404,
            'That code is not part of this demo. Use Ayesha\'s code: $demoCodeSpaced');
      }
      st.status = 'pending';
      st.data['requested_at'] = DateTime.now().toIso8601String();
      st.addLog('request', 'Requested access');
      st.save();
      return _Res(201, {
        'request_id': 'req-ayesha',
        'patient_name': 'Ayesha',
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    if (key == 'POST /doctor/voice/parse') return _Res(200, demoVoiceParse());
    if (key == 'POST /doctor/assistant/ask') {
      final q = '${body['question']}';
      if (body['patient_id'] != null && st.granted) {
        st.addLog('view', 'Asked the AI about the record', scope: 'full');
        return _Res(200, demoAiAnswer(q));
      }
      return _Res(200, demoAssistantAnswer(q, hasAccess: st.granted));
    }
    if (key == 'POST /doctor/break-glass') {
      final code = '${body['medicard_code']}'.replaceAll(' ', '').toUpperCase();
      if (code != demoCode) {
        return _err(404, "That code is not part of this demo. Use Ayesha's code: $demoCodeSpaced");
      }
      final reason = '${body['reason'] ?? ''}'.trim();
      if (reason.length < 4) return _err(422, 'A reason is required for emergency access.');
      st.data['emergency'] = {'at': DateTime.now().toIso8601String(), 'reason': reason};
      st.addLog('break_glass', 'Emergency access: $reason', scope: 'critical');
      return _Res(201, _critical(h, st));
    }
    if (key == 'POST /doctor/grants/grant-em/end') {
      st.data['emergency'] = null;
      st.addLog('end', 'You ended emergency access');
      return _Res(204);
    }
    if (key == 'POST /doctor/grants/grant-1/end') {
      st.status = 'none';
      st.addLog('end', 'You ended access');
      st.save();
      return _Res(204);
    }

    final m = RegExp(r'^/doctor/patients/[^/]+/(.+)$').firstMatch(path);
    if (m == null) return null;
    final sub = m.group(1)!;
    if (sub == 'critical' && !st.granted && st.emergencyActive) {
      return _Res(200, _critical(h, st));
    }
    if (!st.granted) {
      return _err(403, 'You do not have access to this patient. Ask them to approve your request.');
    }
    final shared = recs.where((r) => r['sensitive'] != true).toList();
    final hs = History(shared);

    if (method == 'GET' && sub == 'overview') {
      st.addLog('view', 'Opened the patient overview', scope: 'full');
      st.save();
      return _Res(200, _overview(st, hs, shared));
    }
    if (method == 'GET' && sub == 'records') {
      return _Res(200, [for (final r in _sortedDesc(shared)) _summaryRow(r)]);
    }
    final rm = RegExp(r'^records/(.+)$').firstMatch(sub);
    if (method == 'GET' && rm != null) {
      final rec = shared.where((r) => r['record_id'] == rm.group(1)).firstOrNull;
      return rec == null ? _err(404, 'Record not found') : _Res(200, _detail(rec));
    }
    if (method == 'GET' && sub == 'critical') return _Res(200, _critical(hs, st));
    if (method == 'GET' && sub == 'ai-summary') {
      st.addLog('view', 'Opened the AI summary', scope: 'full');
      st.save();
      return _Res(200, demoAiSummary());
    }
    if (method == 'POST' && sub == 'ai-ask') {
      return _Res(200, demoAiAnswer('${body['question']}'));
    }
    if (method == 'GET' && sub == 'prescribe/context') {
      return _Res(200, {
        'patient_name': 'Ayesha Khan',
        'candidates': hs.meds,
        'known_allergies': hs.allergies,
        'history_alerts': hs.alerts(),
        'assistant_note': 'You are the prescriber. This assistant only lists medicines already '
            'documented for this patient and runs allergy / interaction / duplicate checks on '
            'your draft. It never proposes a new medicine.',
      });
    }
    if (method == 'POST' && sub == 'prescribe/check') {
      return _Res(200, {'checks': _rxChecks(body['medications'] as List? ?? [], hs)});
    }
    if (method == 'POST' && sub == 'prescribe') {
      final meds = (body['medications'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final advice = body['advice'];
      st.data['rx'] = {
        'date': ymd(DateTime.now()),
        'meds': meds,
        'advice': advice,
        'notes': body['notes'],
      };
      st.addLog('prescribe', 'Prescription saved', scope: 'full');
      st.save();
      final rec = _records(st).firstWhere((r) => r['record_id'] == 'r-rx-new');
      return _Res(201, {
        'record': _detail(rec),
        'checks': _rxChecks(meds, hs),
        'care_plan_created': advice != null,
      });
    }
    return null;
  }

  Map<String, dynamic> _emergencyGrant(DemoState st) => {
        'grant_id': 'grant-em',
        'patient_id': demoPatientId,
        'patient_name': 'Ayesha Khan',
        'scope': 'critical',
        'source': 'break_glass',
        'granted_at': (st.emergencyAt ?? DateTime.now()).toUtc().toIso8601String(),
        'expires_at': st.emergencyExpires!.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _critical(History h, DemoState st) => {
        'patient_name': 'Ayesha Khan',
        'allergies': h.allergies,
        'current_medications': h.meds,
        'conditions': h.conditions,
        'note': 'Critical-only view: allergies, current medicines and conditions.',
        'grant': st.emergencyActive && !st.granted ? _emergencyGrant(st) : _grantView(st),
      };

  List<Map<String, dynamic>> _rxChecks(List draft, History h) {
    final out = <Map<String, dynamic>>[];
    final current = h.meds.map((m) => norm('${m['name']}')).toSet();
    for (final raw in draft) {
      final m = Map<String, dynamic>.from(raw as Map);
      final name = '${m['name']}';
      final n = norm(name);
      if (n.isEmpty) continue;
      if (RegExp(r'amoxicillin|penicillin|augmentin|ampicillin').hasMatch(n)) {
        out.add({
          'kind': 'allergy',
          'severity': 'urgent',
          'message': '$name conflicts with a recorded allergy to Penicillin.',
          'drugs': [name],
        });
      }
      if (RegExp(r'ibuprofen|diclofenac|naproxen|ketorolac|aspirin').hasMatch(n)) {
        out.add({
          'kind': 'interaction',
          'severity': 'watch',
          'message': 'NSAID + ACE inhibitor: acute kidney injury risk and reduced BP control. '
              'Check renal function. (ramipril is already on the record)',
          'drugs': [name, 'Ramipril'],
        });
        out.add({
          'kind': 'reaction',
          'severity': 'watch',
          'message': '$name: past reaction on record — Stomach pain and a rise in creatinine '
              '(Aug 2025). Source: Note · ${dMon(daysAgo(300))}.',
          'drugs': [name],
        });
      }
      if (n == 'metformin' && '${m['dose']}'.contains('1000')) {
        out.add({
          'kind': 'reaction',
          'severity': 'watch',
          'message': 'Metformin: past reaction on record — Nausea at 1000 mg; dose reduced to 500 mg '
              '(Jun 2026). Source: Note · ${dMon(daysAgo(110))}.',
          'drugs': [name],
        });
      }
      if (current.contains(n)) {
        out.add({
          'kind': 'duplicate',
          'severity': 'info',
          'message': 'Continues existing $name.',
          'drugs': [name],
        });
      }
    }
    return out;
  }

  Map<String, dynamic> _dashboard(DemoState st, History h) {
    final now = DateTime.now();
    final views = [14, 18, 22, 16, 25, 19, 11];
    final rxs = [6, 8, 9, 7, 11, 8, 5];
    final week = [
      for (var i = 0; i < 7; i++)
        {
          'day': const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][
              now.subtract(Duration(days: 6 - i)).weekday - 1],
          'views': views[i],
          'prescriptions': rxs[i],
        },
    ];
    Map<String, dynamic> act(DateTime at, String action, String name, String text) =>
        {'at': at.toUtc().toIso8601String(), 'action': action, 'patient_name': name, 'text': text};
    final activity = [
      for (final l in st.log)
        act(DateTime.tryParse('${l['at']}') ?? now, '${l['action']}', 'Ayesha', '${l['text']}'),
      act(now.subtract(const Duration(hours: 2)), 'prescribe', 'Hina', 'Prescription saved'),
      act(now.subtract(const Duration(hours: 3)), 'view', 'Zain', 'Opened the patient overview'),
      act(now.subtract(const Duration(hours: 5)), 'grant', 'Zain', 'Patient approved access'),
      act(now.subtract(const Duration(days: 1, hours: 1)), 'view', 'Bilal', 'Opened the AI summary'),
    ];
    return {
      'name': 'Sara Ahmed',
      'specialty': 'Internal Medicine',
      'hospital': 'City Hospital, Lahore',
      'stats': {
        'active_access': (st.granted || st.emergencyActive) ? 1 : 0,
        'pending_requests': st.pending ? 1 : 0,
        'prescriptions_30d': 112 + (st.rx != null ? 1 : 0),
        'patients_seen_30d': 84,
        'emergency_30d': 0,
      },
      'week': week,
      'active': !st.granted && st.emergencyActive
          ? [
              {
                'grant_id': 'grant-em',
                'patient_id': demoPatientId,
                'patient_name': 'Ayesha Khan',
                'age': _age(),
                'gender': 'Female',
                'scope': 'critical',
                'source': 'break_glass',
                'expires_at': st.emergencyExpires!.toUtc().toIso8601String(),
                'alerts': [
                  {'severity': 'urgent', 'text': 'Allergy: Penicillin'},
                ],
              }
            ]
          : st.granted
          ? [
              {
                'grant_id': 'grant-1',
                'patient_id': demoPatientId,
                'patient_name': 'Ayesha Khan',
                'age': _age(),
                'gender': 'Female',
                'scope': 'full',
                'source': 'consent',
                'expires_at': st.expiresAt!.toUtc().toIso8601String(),
                'alerts': [
                  {'severity': 'urgent', 'text': 'Allergy: Penicillin'},
                  {'severity': 'watch', 'text': 'HbA1c has risen at every test (4 results) — last test 4 day(s) ago.'},
                  {'severity': 'watch', 'text': 'Ibuprofen is on her list and she takes ramipril; a past ibuprofen reaction is on record.'},
                ],
              }
            ]
          : [],
      'pending': st.pending
          ? [
              {
                'request_id': 'req-ayesha',
                'patient_name': 'Ayesha',
                'created_at': (st.requestedAt ?? now).toUtc().toIso8601String(),
              }
            ]
          : [],
      'activity': activity.take(8).toList(),
      'schedule': demoSchedule(ayeshaActive: st.granted),
      'brief': {
        'headline': 'Your day at a glance',
        'bullets': [
          '6 patients today — 2 seen, 4 to go.',
          'Next: Ayesha Khan, 10:45 — diabetes review.',
          st.granted
              ? "Ayesha's consent received — her record is open. HbA1c 8.6% and rising (4 tests in a row)."
              : "Ayesha hasn't shared her record yet. Her last HbA1c was 8.6% — rising across 4 tests.",
          'No emergency access in the last 30 days.',
        ],
      },
    };
  }

  int _age() {
    final now = DateTime.now();
    var a = now.year - 1979;
    if (now.month < 4 || (now.month == 4 && now.day < 12)) a--;
    return a;
  }

  Map<String, dynamic> _overview(DemoState st, History h, List<Map<String, dynamic>> recs) {
    final series = h.series;
    Map<String, dynamic>? trend(String name) {
      final pts = series[name];
      if (pts == null || pts.length < 2) return null;
      final last = pts.last;
      return {
        'name': name,
        'unit': last['unit'],
        'latest': last['value'],
        'flag': flagOf(last['value'], last['ref'] as String?),
        'ref': last['ref'],
        'points': [for (final p in pts) {'date': p['date'], 'value': p['value']}],
      };
    }

    final labRows = <Map<String, dynamic>>[];
    for (final r in h.records.where((r) => r['type'] == 'lab' || (dataOf(r)['lab_results'] as List).isNotEmpty)) {
      for (final x in (dataOf(r)['lab_results'] as List).cast<Map>()) {
        labRows.add({
          'name': x['name'],
          'value': '${x['value']}',
          'unit': x['unit'],
          'ref': x['ref_range'],
          'flag': flagOf(x['value'], x['ref_range'] as String?),
          'date': dMonY(DateTime.parse('${r['doc_date']}')),
          'record_id': r['record_id'],
        });
      }
    }
    final plan = _plan(st);
    final nowR = h.records;
    return {
      'patient_id': demoPatientId,
      'name': 'Ayesha Khan',
      'age': _age(),
      'gender': 'Female',
      'blood_group': 'B+',
      'medicard_code': demoCode,
      'address': '12 Jail Road, Lahore',
      'phone': demoPhone,
      'registered_on': dMonY(daysAgo(412)),
      'last_updated': dMonY(DateTime.now()),
      'counts': {
        'conditions': h.conditions.length,
        'medications': h.meds.length,
        'allergies': h.allergies.length,
        'documents': recs.length,
        'lab_tests': h.ofType('lab').fold<int>(0, (n, r) => n + (dataOf(r)['lab_results'] as List).length),
      },
      'latest_labs': labRows.take(6).toList(),
      'upcoming': {'title': 'Follow-up', 'when': dMonY(plan['follow_up'] as DateTime)},
      'conditions': h.conditions,
      'allergies': h.allergies,
      'grant_expires_at': st.expiresAt!.toUtc().toIso8601String(),
      'history_alerts': h.alerts(),
      'trends': [trend('HbA1c'), trend('Fasting glucose'), trend('Creatinine')].whereType<Map<String, dynamic>>().toList(),
      'records': [
        for (final r in nowR)
          {
            'record_id': r['record_id'],
            'type': r['type'],
            'title': recordTitle(r),
            'sub': '${dMonY(DateTime.parse('${r['doc_date']}'))} · ${r['provider']}',
            'verified': true,
            'summary': recordSummary(r),
            'date': dMonY(DateTime.parse('${r['doc_date']}')),
          },
      ],
      'hidden_count': 1,
      'medications': h.meds,
      'tips': [
        {'severity': 'watch', 'text': 'HbA1c has risen at every test (4 results) — last test 4 days ago.'},
        {'severity': 'watch', 'text': 'NSAID + ACE inhibitor: ibuprofen is on her list and she takes ramipril. Check renal function.'},
        {'severity': 'watch', 'text': 'Ibuprofen: past reaction on record — stomach pain and a rise in creatinine (Aug 2025).'},
        {'severity': 'info', 'text': 'No eye or foot check on record for a patient with diabetes.'},
      ],
      'adherence': [
        {'label': 'Medicines taken', 'done': 11, 'total': 14},
        {'label': 'Activity done', 'done': 2, 'total': 7},
        {'label': 'Diet followed', 'done': 5, 'total': 7},
      ],
      'visits': [
        for (final r in h.records.where((r) => r['type'] != 'lab').take(3))
          {'date': r['doc_date'], 'text': '${r['provider']} · ${r['type'] == 'prescription' ? 'Prescription' : 'Note'}'},
      ],
      'advisory_notice': 'Advisory only. This is decision support, not a diagnosis or a prescription. '
          'The licensed physician retains full clinical and prescribing responsibility.',
    };
  }
}
