// Static story for the MVP demo: Ayesha Khan, a 47-year-old with type 2 diabetes and
// hypertension, and her doctor, Dr Sara Ahmed. Nothing here touches a network.

const demoPatientId = 'p-ayesha';
const demoDoctorId = 'd-sara';
const demoCode = '46A9FT39';
const demoCodeSpaced = '46A9 FT39';
const demoPhone = '+923001112222';
const demoDoctorEmail = 'sara.ahmed@medicard-demo.com';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String dMonY(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
String dMon(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
String wdDMon(DateTime d) => '${_days[d.weekday - 1]} ${dMon(d)}';
String monthName(DateTime d) => _months[d.month - 1];

DateTime daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
}

DateTime daysAhead(int n) => daysAgo(-n);

/// Normalised drug name for matching.
String norm(String s) => s.trim().toLowerCase();

Map<String, dynamic> _rec(
  String id,
  String type,
  int ago,
  String provider,
  Map<String, dynamic> data,
) =>
    {
      'record_id': id,
      'type': type,
      'doc_date': ymd(daysAgo(ago)),
      'provider': provider,
      'verified': true,
      'sensitive': false,
      'created_at': daysAgo(ago).toIso8601String(),
      'data': {
        'diagnoses': <String>[],
        'medications': <Map<String, dynamic>>[],
        'lab_results': <Map<String, dynamic>>[],
        'allergies': <String>[],
        'reactions': <Map<String, dynamic>>[],
        'stopped': <Map<String, dynamic>>[],
        'notes': null,
        ...data,
      },
    };

Map<String, dynamic> _lab(String name, String value, String unit, String ref) =>
    {'name': name, 'value': value, 'unit': unit, 'ref_range': ref};

Map<String, dynamic> _med(String name, String dose, String freq, {String route = 'oral'}) =>
    {'name': name, 'dose': dose, 'route': route, 'freq': freq};

/// Ayesha's confirmed history, newest relative to "today" so the demo always looks fresh.
List<Map<String, dynamic>> baseRecords() => [
      _rec('r1', 'note', 410, 'Dr Sara Ahmed · City Hospital', {
        'diagnoses': ['Type 2 diabetes mellitus', 'Essential hypertension'],
        'allergies': ['Penicillin'],
        'notes': 'New diagnosis. Started on metformin. Lifestyle advice given.',
      }),
      _rec('r2', 'lab', 400, 'Chughtai Lab', {
        'lab_results': [
          _lab('HbA1c', '7.2', '%', '<7'),
          _lab('Fasting glucose', '138', 'mg/dL', '70-100'),
          _lab('Creatinine', '0.9', 'mg/dL', '0.6-1.1'),
        ],
      }),
      _rec('r3', 'prescription', 395, 'Dr Sara Ahmed · City Hospital', {
        'diagnoses': ['Type 2 diabetes mellitus', 'Essential hypertension'],
        'medications': [
          _med('Metformin', '500 mg', 'twice daily'),
          _med('Amlodipine', '5 mg', 'once daily'),
        ],
        'allergies': ['Penicillin'],
      }),
      _rec('r4', 'note', 300, 'Dr Sara Ahmed · City Hospital', {
        'diagnoses': ['Type 2 diabetes mellitus', 'Essential hypertension'],
        'reactions': [
          {'drug': 'Ibuprofen', 'effect': 'Stomach pain and a rise in creatinine', 'date': 'Aug 2025'},
        ],
        'stopped': [
          {'name': 'Amlodipine', 'reason': 'Ankle swelling; switched to ramipril', 'date': '2025'},
        ],
        'notes': 'Ankle swelling on amlodipine. Switched to ramipril.',
      }),
      _rec('r5', 'lab', 240, 'Chughtai Lab', {
        'lab_results': [
          _lab('HbA1c', '7.4', '%', '<7'),
          _lab('Fasting glucose', '146', 'mg/dL', '70-100'),
          _lab('Creatinine', '0.9', 'mg/dL', '0.6-1.1'),
        ],
      }),
      _rec('r6', 'prescription', 235, 'Dr Sara Ahmed · City Hospital', {
        'diagnoses': ['Type 2 diabetes mellitus', 'Essential hypertension', 'High cholesterol'],
        'medications': [
          _med('Metformin', '500 mg', 'twice daily'),
          _med('Ramipril', '5 mg', 'once daily, at night'),
          _med('Atorvastatin', '10 mg', 'once daily, at night'),
        ],
        'allergies': ['Penicillin'],
      }),
      _rec('r7', 'lab', 120, 'Chughtai Lab', {
        'lab_results': [
          _lab('HbA1c', '8.1', '%', '<7'),
          _lab('Fasting glucose', '158', 'mg/dL', '70-100'),
          _lab('Creatinine', '0.9', 'mg/dL', '0.6-1.1'),
        ],
      }),
      _rec('r8', 'note', 110, 'Dr Sara Ahmed · City Hospital', {
        'diagnoses': ['Type 2 diabetes mellitus', 'Essential hypertension', 'High cholesterol'],
        'reactions': [
          {
            'drug': 'Metformin',
            'effect': 'Nausea at 1000 mg; dose reduced to 500 mg',
            'date': 'Jun 2026',
          },
        ],
        'lab_results': [_lab('Systolic blood pressure', '138', 'mmHg', '<130')],
        'notes': 'Review. Metformin reduced after nausea. BP slightly above target.',
      }),
      _rec('r9', 'lab', 45, 'Chughtai Lab', {
        'lab_results': [
          _lab('Total cholesterol', '182', 'mg/dL', '<200'),
          _lab('LDL cholesterol', '96', 'mg/dL', '<100'),
        ],
      }),
      _rec('r10', 'prescription', 40, 'Dr Sara Ahmed · City Hospital', {
        'diagnoses': [
          'Type 2 diabetes mellitus',
          'Essential hypertension',
          'High cholesterol',
          'Knee osteoarthritis',
        ],
        'medications': [
          _med('Metformin', '500 mg', 'twice daily'),
          _med('Ramipril', '5 mg', 'once daily, at night'),
          _med('Atorvastatin', '10 mg', 'once daily, at night'),
          _med('Ibuprofen', '400 mg', 'when needed'),
        ],
        'allergies': ['Penicillin'],
        'notes': 'Knee pain; NSAID started as needed.',
      }),
      _rec('r11', 'lab', 4, 'Chughtai Lab', {
        'lab_results': [
          _lab('HbA1c', '8.6', '%', '<7'),
          _lab('Fasting glucose', '164', 'mg/dL', '70-100'),
          _lab('Creatinine', '1.0', 'mg/dL', '0.6-1.1'),
        ],
      }),
    ];

// ------------------------------------------------------------------- helpers

double? _num(Object? v) => double.tryParse('${v ?? ''}'.replaceAll(',', '').trim());

/// 'high' | 'low' | 'normal' | 'unknown'
String flagOf(Object? value, String? ref) {
  final x = _num(value);
  if (x == null || ref == null) return 'unknown';
  final r = ref.replaceAll('–', '-').trim();
  final lt = RegExp(r'^<\s*=?\s*([\d.]+)$').firstMatch(r);
  if (lt != null) return x > double.parse(lt.group(1)!) ? 'high' : 'normal';
  final gt = RegExp(r'^>\s*=?\s*([\d.]+)$').firstMatch(r);
  if (gt != null) return x < double.parse(gt.group(1)!) ? 'low' : 'normal';
  final range = RegExp(r'^([\d.]+)\s*-\s*([\d.]+)$').firstMatch(r);
  if (range != null) {
    final lo = double.parse(range.group(1)!);
    final hi = double.parse(range.group(2)!);
    return x < lo ? 'low' : x > hi ? 'high' : 'normal';
  }
  return 'unknown';
}

List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> recs) {
  final out = [...recs];
  out.sort((a, b) => (b['doc_date'] as String).compareTo(a['doc_date'] as String));
  return out;
}

Map<String, dynamic> dataOf(Map<String, dynamic> r) =>
    Map<String, dynamic>.from(r['data'] as Map);

List<Map<String, dynamic>> _listOf(Object? v) =>
    (v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// Read-only queries over a record list (newest first where it matters).
class History {
  History(List<Map<String, dynamic>> records) : records = _sorted(records);
  final List<Map<String, dynamic>> records;

  Iterable<Map<String, dynamic>> ofType(String t) => records.where((r) => r['type'] == t);

  List<String> get conditions {
    final seen = <String, String>{};
    for (final r in records) {
      for (final d in (dataOf(r)['diagnoses'] as List? ?? [])) {
        seen.putIfAbsent('$d'.toLowerCase(), () => '$d');
      }
    }
    return seen.values.toList();
  }

  List<String> get allergies {
    final s = <String>{};
    for (final r in records) {
      for (final a in (dataOf(r)['allergies'] as List? ?? [])) {
        s.add('$a');
      }
    }
    return s.toList()..sort();
  }

  /// Current medicines: newest prescription wins, deduped by name.
  List<Map<String, dynamic>> get meds {
    // A medicine the record says was stopped is no longer current.
    final stopped = <String>{
      for (final r in records)
        for (final x in _listOf(dataOf(r)['stopped'])) norm('${x['name']}'),
    };
    final seen = <String>{...stopped};
    final out = <Map<String, dynamic>>[];
    for (final r in ofType('prescription')) {
      for (final m in _listOf(dataOf(r)['medications'])) {
        final k = norm('${m['name']}');
        if (k.isEmpty || !seen.add(k)) continue;
        out.add({
          ...m,
          'source_record_id': r['record_id'],
          'source_date': r['doc_date'],
        });
      }
    }
    return out;
  }

  /// name -> points oldest first {date, value, unit, ref, record_id}
  Map<String, List<Map<String, dynamic>>> get series {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final r in records.reversed.where((r) => r['type'] == 'lab' || r['type'] == 'note')) {
      for (final x in _listOf(dataOf(r)['lab_results'])) {
        final v = _num(x['value']);
        if (v == null) continue;
        out.putIfAbsent('${x['name']}', () => []).add({
          'date': r['doc_date'],
          'value': v,
          'unit': x['unit'],
          'ref': x['ref_range'],
          'record_id': r['record_id'],
        });
      }
    }
    return out;
  }

  List<Map<String, dynamic>> alerts() {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    void add(String kind, String title, String text, Map<String, dynamic> r, String sev) {
      if (!seen.add('$kind|${title.toLowerCase()}')) return;
      out.add({
        'kind': kind,
        'severity': sev,
        'title': title,
        'text': text,
        'source_record_id': r['record_id'],
        'source_label': '${_typeLabel(r['type'] as String)} · ${dMon(DateTime.parse(r['doc_date'] as String))}',
      });
    }

    for (final r in records) {
      final d = dataOf(r);
      for (final a in (d['allergies'] as List? ?? [])) {
        add('allergy', '$a', 'Documented allergy.', r, 'urgent');
      }
      for (final x in _listOf(d['reactions'])) {
        add('reaction', '${x['drug']}', '${x['effect']} (${x['date']})', r, 'watch');
      }
      for (final x in _listOf(d['stopped'])) {
        add('stopped', '${x['name']} stopped', 'Stopped — ${x['reason']} (${x['date']})', r, 'info');
      }
    }
    const order = {'urgent': 0, 'watch': 1, 'info': 2};
    out.sort((a, b) => order[a['severity']]!.compareTo(order[b['severity']]!));
    return out;
  }
}

String _typeLabel(String t) => switch (t) {
      'lab' => 'Lab',
      'prescription' => 'Prescription',
      'imaging' => 'Imaging',
      _ => 'Note',
    };

String recordTitle(Map<String, dynamic> r) {
  final d = dataOf(r);
  switch (r['type']) {
    case 'lab':
      final labs = _listOf(d['lab_results']);
      return labs.isEmpty ? 'Lab report' : '${labs.first['name']} · Lab report';
    case 'prescription':
      final n = _listOf(d['medications']).length;
      return 'Prescription · $n medicine${n == 1 ? '' : 's'}';
    case 'imaging':
      return 'Imaging';
    default:
      return 'Clinic note';
  }
}

String? recordSummary(Map<String, dynamic> r) {
  final d = dataOf(r);
  if (r['type'] == 'lab') {
    final labs = _listOf(d['lab_results']);
    if (labs.isNotEmpty) {
      final f = flagOf(labs.first['value'], labs.first['ref_range'] as String?);
      final tail = f == 'high' || f == 'low' ? ' (${f[0].toUpperCase()}${f.substring(1)})' : '';
      return 'Result: ${labs.first['value']} ${labs.first['unit'] ?? ''}$tail'.trim();
    }
  }
  if (r['type'] == 'prescription') {
    final names = _listOf(d['medications']).map((m) => '${m['name']}').join(', ');
    if (names.isNotEmpty) return names;
  }
  return d['notes'] as String?;
}

// ---- the static "AI" (summary, answers, voice) — written once, perfectly ----

const demoQuestions = <String>[
  'How has her HbA1c changed?',
  'Any documented drug allergy?',
  'Has she had problems with any medicine before?',
  'Is it safe to continue ibuprofen?',
  'Summarise her last 3 visits',
];

Map<String, dynamic> demoAiSummary() => {
      'summary': 'Ayesha Khan, 47, has type 2 diabetes, hypertension and high cholesterol. '
          'Her HbA1c has risen at every test over 13 months (7.2%, 7.4%, 8.1% and 8.6%) '
          'and fasting glucose has followed (138 up to 164 mg/dL). Blood pressure and cholesterol '
          'are close to target. She has a documented penicillin allergy and past reactions to '
          'ibuprofen and to a higher metformin dose.',
      'flags': [
        {
          'text': 'HbA1c has risen at every test — 7.2%, 7.4%, 8.1%, 8.6% — and is above the '
              'reference range (<7%). The last review was 40 days ago.',
          'severity': 'watch',
          'source_record_ids': ['r2', 'r5', 'r7', 'r11'],
        },
        {
          'text': 'Ibuprofen is on her current list alongside ramipril (an ACE inhibitor). This '
              'combination is commonly flagged for kidney and blood-pressure effects, and a past '
              'ibuprofen reaction (stomach pain, raised creatinine) is on record. Last creatinine '
              '1.0 mg/dL.',
          'severity': 'urgent',
          'source_record_ids': ['r10', 'r4', 'r11'],
        },
        {
          'text': 'Penicillin allergy documented. No current medicine is a penicillin.',
          'severity': 'info',
          'source_record_ids': ['r1', 'r10'],
        },
      ],
      'relevant_history': [
        'Metformin 1000 mg caused nausea (Jun 2026); reduced to 500 mg twice daily.',
        'Amlodipine stopped in 2025 for ankle swelling; switched to ramipril.',
        'Systolic BP 138 mmHg at last recorded check (target <130).',
      ],
      'model': 'demo',
      'advisory_notice': 'Advisory only. This is decision support, not a diagnosis or a '
          'prescription. The licensed physician retains full clinical and prescribing responsibility.',
    };

Map<String, dynamic> demoAiAnswer(String q) {
  final s = q.toLowerCase();
  Map<String, dynamic> a(String text, List<String> ids) => {
        'answer': text,
        'source_record_ids': ids,
        'answered_from_records': true,
        'advisory_notice': 'Advisory only. The physician makes the clinical decision.',
      };
  if (s.contains('hba1c') || s.contains('sugar') || s.contains('glucose') || s.contains('changed')) {
    return a(
        'Her HbA1c has risen at every test: 7.2% (13 months ago), 7.4%, 8.1%, and 8.6% four days '
        'ago — all above the <7% reference. Fasting glucose moved the same way: 138, 146, 158 and '
        '164 mg/dL.',
        ['r2', 'r5', 'r7', 'r11']);
  }
  if (s.contains('allerg')) {
    return a(
        'Yes — penicillin allergy is documented (first recorded 13 months ago and repeated on '
        'the latest prescription). No other drug allergies are on record.',
        ['r1', 'r10']);
  }
  if (s.contains('problem') || s.contains('reaction') || s.contains('before') || s.contains('side')) {
    return a(
        'Two past medicine effects are on record: (1) Ibuprofen — stomach pain and a rise in '
        'creatinine (Aug 2025). (2) Metformin 1000 mg — nausea; the dose was reduced to 500 mg twice '
        'daily (Jun 2026). Amlodipine was also stopped for ankle swelling (2025).',
        ['r4', 'r8']);
  }
  if (s.contains('ibuprofen') || s.contains('nsaid') || s.contains('safe')) {
    return a(
        'I can\'t advise on prescribing, but the record shows: ibuprofen 400 mg as needed is on her '
        'current list; she takes ramipril (ACE inhibitor); a past ibuprofen reaction is documented; '
        'creatinine was 1.0 mg/dL four days ago. These are the points to weigh — the decision is '
        'yours.',
        ['r10', 'r4', 'r11']);
  }
  if (s.contains('visit') || s.contains('summar') || s.contains('last')) {
    return a(
        'Last 3 visits: (1) 40 days ago — prescription with ibuprofen added for knee pain. '
        '(2) 110 days ago — metformin reduced to 500 mg after nausea; BP 138 mmHg. '
        '(3) 235 days ago — ramipril and atorvastatin started. HbA1c has climbed across them.',
        ['r10', 'r8', 'r6']);
  }
  return {
    'answer': 'That is not answerable from the shared records. Try one of the suggested questions.',
    'source_record_ids': <String>[],
    'answered_from_records': false,
    'advisory_notice': 'Advisory only. The physician makes the clinical decision.',
  };
}

Map<String, dynamic> demoPatientAnswer(String q) {
  final s = q.toLowerCase();
  Map<String, dynamic> a(String text, List<String> ids) => {
        'answer': text,
        'answered_from_records': true,
        'source_record_ids': ids,
        'notice': 'Answers come only from your own records. For emergencies, call your doctor.',
      };
  if (s.contains('sugar') || s.contains('report') || s.contains('hba1c')) {
    return a(
        'Your sugar test (HbA1c) is 8.6%. A healthy level is below 7%. It has gone up in your last '
        '4 tests (7.2, then 7.4, 8.1 and 8.6), so your sugar is not well controlled right now. Keep '
        'taking Metformin every day, follow the low-sugar diet, and walk after dinner. Show this '
        'report to Dr Sara at your next visit.',
        ['r11']);
  }
  if (s.contains('medicine') || s.contains('tablet') || s.contains('dawa')) {
    return a(
        'Metformin lowers your sugar. Ramipril controls blood pressure and protects your kidneys. '
        'Atorvastatin lowers cholesterol. Ibuprofen is only for knee pain when needed — your '
        'records show it once upset your stomach, so please ask Dr Sara before using it.',
        ['r10']);
  }
  if (s.contains('ibuprofen') || s.contains('knee') || s.contains('painkiller') || s.contains('pain')) {
    return a(
        'I can\'t tell you whether to take a medicine — please ask Dr Sara first. What your '
        'records show: ibuprofen is on your list only for knee pain when needed, it once upset your '
        'stomach and affected your kidney test (Aug 2025), and you also take ramipril. Many people '
        'with these records are told to avoid it. Please check with your doctor before using it.',
        ['r10', 'r4']);
  }
  if (s.contains('eat') || s.contains('diet') || s.contains('food') || s.contains('chai')) {
    return a(
        'Dr Sara advised a low-sugar diet. Eat more: daal and sabzi, salad, daliya, plain yogurt. '
        'Eat less: sugar in chai, mithai, fried food, cold drinks.',
        ['r10']);
  }
  if (s.contains('test') || s.contains('next') || s.contains('when') || s.contains('appointment')) {
    return a(
        'Next: a fasting sugar test on ${wdDMon(daysAhead(6))}, your follow-up with Dr Sara on '
        '${wdDMon(daysAhead(14))}, and a repeat HbA1c test on ${wdDMon(daysAhead(33))}.',
        ['r10']);
  }
  return {
    'answer': 'I can only answer from your own records. Try asking about your reports, medicines, '
        'diet or next test — or ask your doctor.',
    'answered_from_records': false,
    'source_record_ids': <String>[],
    'notice': 'Answers come only from your own records. For emergencies, call your doctor.',
  };
}

const demoDictation =
    'Patient reports tiredness and increased thirst for two weeks. Sugar rising. '
    'Metformin five hundred twice daily for thirty days, Ramipril five milligram once daily, '
    'Atorvastatin ten once daily. Low sugar diet, walk twenty minutes, review in two weeks. '
    'Repeat HbA1c in six weeks.';

Map<String, dynamic> demoVoiceParse() => {
      'note': {
        'complaint': 'Patient reports tiredness and increased thirst for two weeks.',
        'assessment': 'Sugar rising (HbA1c 8.6%).',
        'plan': 'Low sugar diet, walk twenty minutes, review in two weeks. '
            'Repeat HbA1c in six weeks.',
      },
      'medications': [
        {'name': 'Metformin', 'dose': '500 mg', 'freq': 'Twice daily', 'days': '30 days'},
        {'name': 'Ramipril', 'dose': '5 mg', 'freq': 'Once daily', 'days': '30 days'},
        {'name': 'Atorvastatin', 'dose': '10 mg', 'freq': 'Once daily, at night', 'days': '30 days'},
      ],
      'advice': {
        'diet': {
          'note': 'Low-sugar diet',
          'more': ['Daal and sabzi', 'Salad', 'Daliya', 'Plain yogurt'],
          'less': ['Sugar in chai', 'Mithai', 'Fried food', 'Cold drinks'],
        },
        'activity': ['Walk 20 minutes'],
        'tests': [
          {'name': 'HbA1c test', 'in_days': 42},
        ],
        'follow_up_days': 14,
      },
      'notice': 'Written from your dictation. Check every field — nothing is saved until you confirm.',
    };

/// Doctor's schedule for the day. Only Ayesha is "active" in the demo.
List<Map<String, dynamic>> demoSchedule({required bool ayeshaActive}) => [
      {'name': 'Zain Malik', 'time': '09:30', 'reason': 'Asthma review', 'status': 'done', 'active': false},
      {'name': 'Hina Rauf', 'time': '10:10', 'reason': 'Blood pressure check', 'status': 'done', 'active': false},
      {
        'name': 'Ayesha Khan',
        'time': '10:45',
        'reason': 'Diabetes review · HbA1c follow-up',
        'status': ayeshaActive ? 'in_consultation' : 'waiting',
        'active': true,
        'patient_id': demoPatientId,
        'code_hint': demoCodeSpaced,
      },
      {'name': 'Bilal Ahmed', 'time': '11:30', 'reason': 'Fever and cough', 'status': 'waiting', 'active': false},
      {'name': 'Sana Tariq', 'time': '12:15', 'reason': 'Thyroid follow-up', 'status': 'waiting', 'active': false},
      {'name': 'Usman Ali', 'time': '12:50', 'reason': 'Back pain', 'status': 'waiting', 'active': false},
    ];

/// What the "scan a document" demo extracts (low-confidence fields get a "please check" chip).
Map<String, dynamic> demoExtractionDraft() => {
      'diagnoses': <String>[],
      'medications': <Map<String, dynamic>>[],
      'lab_results': [
        {'name': 'LDL cholesterol', 'value': '112', 'unit': 'mg/dL', 'ref_range': '<100'},
        {'name': 'HDL cholesterol', 'value': '48', 'unit': 'mg/dL', 'ref_range': '>40'},
        {'name': 'Triglycerides', 'value': '168', 'unit': 'mg/dL', 'ref_range': '<150'},
        {'name': 'Total cholesterol', 'value': '186', 'unit': 'mg/dL', 'ref_range': '<200'},
        {'name': 'VLDL cholesterol', 'value': '34', 'unit': 'mg/dL', 'ref_range': '5-40'},
      ],
      'allergies': <String>[],
      'notes': null,
    };


const demoDoctorDayQuestions = <String>[
  'Who needs my attention today?',
  "What's on my schedule?",
  'Prepare me for Ayesha Khan',
  'Any urgent flags across my patients?',
];

const demoPatientChatQuestions = <String>[
  'What does my sugar report mean?',
  'What is each medicine for?',
  'What can I eat?',
  'When is my next test?',
  'Can I take ibuprofen for my knee pain?',
];

/// The doctor's assistant for day-level questions (no patient open).
Map<String, dynamic> demoAssistantAnswer(String q, {required bool hasAccess}) {
  final s = q.toLowerCase();
  Map<String, dynamic> a(String text, {List<String> ids = const [], bool from = true}) => {
        'answer': text,
        'source_record_ids': ids,
        'answered_from_records': from,
        'advisory_notice': 'Advisory only. The physician makes the clinical decision.',
      };
  if (s.contains('attention') || s.contains('urgent') || s.contains('flag') || s.contains('priority')) {
    return a(
        'Of 6 patients today, 2 are already seen. Only Ayesha Khan has shared her records with you '
        '${hasAccess ? 'right now' : '(waiting for her approval)'}, and she is the one to look at first: '
        'HbA1c has risen at every test (7.2%, 7.4%, 8.1% and 8.6%), and ibuprofen sits next to ramipril '
        'with a past ibuprofen reaction on record. The other patients will show flags once they '
        'approve access.',
        ids: hasAccess ? ['r11', 'r10', 'r4'] : []);
  }
  if (s.contains('schedule') || s.contains('today') || s.contains('who')) {
    return a(
        'Today: 09:30 Zain Malik (asthma review, seen) · 10:10 Hina Rauf (BP check, seen) · '
        '10:45 Ayesha Khan (diabetes review — next) · 11:30 Bilal Ahmed (fever and cough) · '
        '12:15 Sana Tariq (thyroid follow-up) · 12:50 Usman Ali (back pain).');
  }
  if (s.contains('ayesha') || s.contains('prepare') || s.contains('consult')) {
    return a(
        hasAccess
            ? 'For Ayesha (47, type 2 diabetes + hypertension + high cholesterol): HbA1c 8.6% and rising '
                'for 13 months; fasting glucose 164. BP 138 systolic at last check. Penicillin allergy. '
                'Past effects: ibuprofen (stomach pain, creatinine rise), metformin 1000 mg (nausea). '
                'Ibuprofen is on her current list with ramipril — worth discussing. Last creatinine 1.0.'
            : 'I can prepare you as soon as Ayesha approves access — enter her code (46A9 FT39) in the '
                'search box at the top.',
        ids: hasAccess ? ['r11', 'r10', 'r8', 'r4'] : [],
        from: hasAccess);
  }
  return a(
      'I can help with your day (schedule, who needs attention) or, once a patient has approved '
      'access, with their record. Try one of the suggested questions.',
      from: false);
}
