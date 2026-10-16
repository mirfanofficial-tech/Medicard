import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env.dart';
import '../../core/language.dart';
import '../../demo/demo_data.dart' show demoDictation;
import '../../core/voice_input.dart';
import '../../theme.dart';
import '../access/access_repository.dart';
import '../access/models.dart';
import 'patient_records_screen.dart';

class _Line {
  _Line({
    this.name = '',
    this.dose = '',
    this.route = '',
    this.freq = '',
    this.days = '',
    this.origin = 'manual',
    this.fromCandidateId,
  });

  String name;
  String dose;
  String route;
  String freq;
  String days;
  String origin; // manual | history
  String? fromCandidateId;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'dose': dose.trim().isEmpty ? null : dose.trim(),
        'route': route.trim().isEmpty ? null : route.trim(),
        'freq': freq.trim().isEmpty ? null : freq.trim(),
        'days': days.trim().isEmpty ? null : days.trim(),
        'origin': origin,
      };
}

class PrescribeScreen extends ConsumerStatefulWidget {
  const PrescribeScreen({super.key, required this.patientId, this.initialDictation});

  final String patientId;

  /// Text dictated on the overview screen, to be written into the draft on open.
  final String? initialDictation;

  @override
  ConsumerState<PrescribeScreen> createState() => _State();
}

class _State extends ConsumerState<PrescribeScreen> {
  RxContext? _ctx;
  final List<_Line> _draft = [];
  final _notes = TextEditingController();
  final _voice = VoiceInput();
  final _dictation = TextEditingController();
  final _dietNote = TextEditingController();
  final _activity = TextEditingController();
  final _followUp = TextEditingController();
  List<String> _eatMore = [];
  List<String> _eatLess = [];
  List<({String name, int inDays})> _tests = [];
  bool _parsing = false;
  List<RxCheck> _checks = [];
  bool _loading = true;
  bool _saving = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _voice.addListener(() => mounted ? setState(() {}) : null);
    _load();
  }

  @override
  void dispose() {
    for (final c in [_notes, _dictation, _dietNote, _activity, _followUp]) {
      c.dispose();
    }
    _voice.dispose();
    super.dispose();
  }

  Future<void> _parseDictation() async {
    final text = _dictation.text.trim();
    if (text.length < 3) return;
    setState(() {
      _parsing = true;
      _error = null;
    });
    try {
      final d = await _repo.voiceParse(text);
      setState(() {
        for (final m in d.meds) {
          final exists = _draft.any((l) => l.name.toLowerCase() == m.name.toLowerCase());
          if (exists) continue;
          _draft.add(_Line(
            name: m.name,
            dose: m.dose ?? '',
            freq: m.freq ?? '',
            days: m.days ?? '',
          ));
        }
        final note = [d.complaint, d.assessment, d.plan].whereType<String>().join(' ');
        if (note.isNotEmpty && _notes.text.trim().isEmpty) _notes.text = note;
        if (d.dietNote != null) {
          _dietNote.text = d.dietNote!;
          _eatMore = d.eatMore;
          _eatLess = d.eatLess;
        }
        if (d.activity.isNotEmpty) _activity.text = d.activity.join(', ');
        if (d.followUpDays != null) _followUp.text = '${d.followUpDays}';
        if (d.tests.isNotEmpty) _tests = d.tests;
      });
      await _recheck();
    } on DioException {
      setState(() => _error = 'Could not write from your dictation. Please try again.');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _mic() async {
    if (_voice.listening) {
      await _voice.stop();
      await _parseDictation();
      return;
    }
    await _voice.start(
      urdu: ref.read(urduProvider),
      onText: (t, _) => _dictation.text = t,
    );
  }

  Map<String, dynamic>? get _advice {
    final activity = _activity.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final days = int.tryParse(_followUp.text.trim());
    final diet = _dietNote.text.trim();
    if (diet.isEmpty && activity.isEmpty && _tests.isEmpty && days == null) return null;
    return {
      'diet': diet.isEmpty ? null : {'note': diet, 'more': _eatMore, 'less': _eatLess},
      'activity': activity,
      'tests': [for (final t in _tests) {'name': t.name, 'in_days': t.inDays}],
      'follow_up_days': days,
    };
  }

  AccessRepository get _repo => ref.read(accessRepositoryProvider);

  Future<void> _load() async {
    try {
      final c = await _repo.prescribeContext(widget.patientId);
      setState(() {
        _ctx = c;
        _loading = false;
      });
      final first = widget.initialDictation;
      if (first != null && first.isNotEmpty && _dictation.text.isEmpty) {
        _dictation.text = first;
        await _parseDictation();
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ?? 'Could not load';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _named =>
      _draft.where((l) => l.name.trim().isNotEmpty).map((l) => l.toJson()).toList();

  Future<void> _recheck() async {
    if (_named.isEmpty) {
      setState(() => _checks = []);
      return;
    }
    setState(() => _checking = true);
    try {
      final c = await _repo.prescribeCheck(widget.patientId, _named);
      setState(() => _checks = c);
    } on DioException {
      // leave prior checks
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  bool _isPicked(RxCandidate c) =>
      _draft.any((l) => l.fromCandidateId == c.sourceRecordId && l.name == c.name);

  void _toggleCandidate(RxCandidate c, bool on) {
    setState(() {
      if (on) {
        _draft.add(_Line(
          name: c.name,
          dose: c.dose ?? '',
          route: c.route ?? '',
          freq: c.freq ?? '',
          origin: 'history',
          fromCandidateId: c.sourceRecordId,
        ));
      } else {
        _draft.removeWhere(
          (l) => l.fromCandidateId == c.sourceRecordId && l.name == c.name,
        );
      }
    });
    _recheck();
  }

  Future<void> _save() async {
    if (_named.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final warnings = await _repo.prescribeCreate(
        widget.patientId,
        medications: _named,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        advice: _advice,
      );
      ref.invalidate(doctorRecordsProvider(widget.patientId));
      if (!mounted) return;
      final urgent = warnings.where((w) => w.severity == 'urgent').length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(urgent > 0
            ? 'Prescription saved with $urgent urgent warning(s).'
            : 'Prescription saved to the patient record.'),
      ));
      context.go('/doctor/patients/${widget.patientId}/records');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Could not save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write prescription'),
        leading: BackButton(
          onPressed: () => context.go('/doctor/patients/${widget.patientId}/records'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ctx == null
              ? Center(child: Text(_error ?? 'Unavailable'))
              : _form(),
    );
  }

  Widget _form() {
    final ctx = _ctx!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MediCardColors.unverified.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ctx.knownAllergies.isEmpty
                ? 'No allergies on file.'
                : 'Allergies on file: ${ctx.knownAllergies.join(', ')}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        Text(ctx.assistantNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        _dictationCard(),
        if (ctx.historyAlerts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _historyCard(ctx),
        ],
        const Divider(height: 24),

        Text("From ${ctx.patientName.split(' ').first}'s record",
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (ctx.candidates.isEmpty)
          const Text('No medications documented for this patient.')
        else
          for (final c in ctx.candidates)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _isPicked(c),
              onChanged: (v) => _toggleCandidate(c, v ?? false),
              title: Text(
                '${c.name}'
                '${c.dose != null && c.dose!.isNotEmpty ? ' ${c.dose}' : ''}'
                '${c.freq != null && c.freq!.isNotEmpty ? ' · ${c.freq}' : ''}',
              ),
              subtitle: Text('from ${c.sourceDate ?? 'record'}'),
            ),

        const Divider(height: 24),
        Row(children: [
          Text('Prescription', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() => _draft.add(_Line()));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ]),
        if (_draft.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Tick a medicine above, or add one.'),
          ),
        for (var i = 0; i < _draft.length; i++) _lineEditor(i),

        const SizedBox(height: 14),
        _adviceCard(),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
        ),

        const Divider(height: 24),
        Row(children: [
          Text('Checks on your draft', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          TextButton.icon(
            onPressed: _checking ? null : _recheck,
            icon: const Icon(Icons.refresh),
            label: Text(_checking ? '...' : 'Re-check'),
          ),
        ]),
        if (_checks.isEmpty)
          const Text('No allergy, interaction or duplicate flags on the current draft.')
        else
          for (final c in _checks) _checkTile(c),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving || _named.isEmpty ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save prescription'),
        ),
        const SizedBox(height: 8),
        const Text(
          'You are the prescriber and are responsible for this prescription.',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _lineEditor(int i) {
    final l = _draft[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: l.name,
                  decoration: const InputDecoration(labelText: 'Medicine', isDense: true),
                  onChanged: (v) => l.name = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: l.dose,
                  decoration: const InputDecoration(labelText: 'Dose', isDense: true),
                  onChanged: (v) => l.dose = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _draft.removeAt(i));
                  _recheck();
                },
              ),
            ]),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: l.freq,
                  decoration: const InputDecoration(labelText: 'Frequency', isDense: true),
                  onChanged: (v) => l.freq = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: l.route,
                  decoration: const InputDecoration(labelText: 'Route', isDense: true),
                  onChanged: (v) => l.route = v,
                ),
              ),
              if (l.origin == 'history')
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Chip(
                    label: Text('from record', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: l.days,
                  decoration: const InputDecoration(labelText: 'For how long', isDense: true),
                  onChanged: (v) => l.days = v,
                ),
              ),
            ]),
            for (final c in _checks.where((c) =>
                c.kind == 'reaction' &&
                c.drugs.any((d) => d.toLowerCase() == l.name.trim().toLowerCase())))
              Container(
                margin: const EdgeInsets.only(top: 8, right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('From this patient\'s history: ${c.message}',
                        style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _checkTile(RxCheck c) {
    final color = switch (c.severity) {
      'urgent' => MediCardColors.danger,
      'watch' => MediCardColors.unverified,
      _ => MediCardColors.seed,
    };
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          switch (c.kind) {
            'allergy' => Icons.dangerous,
            'interaction' => Icons.warning_amber,
            'reaction' => Icons.history,
            _ => Icons.info_outline,
          },
          color: color,
        ),
        title: Text(c.message),
        subtitle: Text('${c.kind} · ${c.severity}'
            '${c.drugs.isNotEmpty ? ' · ${c.drugs.join(' + ')}' : ''}'),
      ),
    );
  }

  Widget _dictationCard() {
    final listening = _voice.listening;
    final urdu = ref.watch(urduProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MediCardColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
            onTap: _mic,
            customBorder: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening ? MediCardColors.danger : MediCardColors.primary,
              ),
              child: Icon(listening ? Icons.stop : Icons.mic, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Tap and speak the prescription',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('EN')),
              ButtonSegment(value: true, label: Text('اردو')),
            ],
            selected: {urdu},
            onSelectionChanged: (v) => ref.read(urduProvider.notifier).state = v.first,
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _dictation,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'e.g. “Metformin five hundred twice daily for thirty days… low sugar diet, '
                'walk twenty minutes, review in two weeks.”',
          ),
        ),
        if (_voice.error != null && !listening)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${_voice.error!} You can type instead.',
                style: const TextStyle(fontSize: 12, color: MediCardColors.danger)),
          ),
        if (Env.demo)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ActionChip(
              avatar: const Icon(Icons.bolt, size: 16),
              label: const Text('Use sample dictation'),
              onPressed: () => setState(() => _dictation.text = demoDictation),
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [
          FilledButton.icon(
            onPressed: _parsing ? null : _parseDictation,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(_parsing ? 'Writing…' : 'Write it for me'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Only what you say is written. Check every line.',
                style: TextStyle(fontSize: 12, color: MediCardColors.muted)),
          ),
        ]),
      ]),
    );
  }

  Widget _historyCard(RxContext ctx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MediCardColors.primary, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Her history at a glance',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final a in ctx.historyAlerts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: switch (a.kind) {
                  'allergy' => 'Allergy',
                  'reaction' => 'Past effect',
                  _ => 'Stopped',
                },
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: a.severity == 'urgent'
                        ? MediCardColors.danger
                        : a.severity == 'watch'
                            ? MediCardColors.warning
                            : MediCardColors.muted),
              ),
              TextSpan(text: ' · ${a.title}: ${a.text}  (${a.sourceLabel})'),
            ]), style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
      ]),
    );
  }

  Widget _adviceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MediCardColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(
            child: Text('Advice for the patient',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          ),
          Text('Becomes their care plan',
              style: TextStyle(
                  fontSize: 12, color: MediCardColors.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _dietNote,
          decoration: const InputDecoration(labelText: 'Diet', hintText: 'e.g. Low-sugar diet'),
        ),
        if (_eatMore.isNotEmpty || _eatLess.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Eat more: ${_eatMore.join(', ')}  ·  Eat less: ${_eatLess.join(', ')}',
                style: const TextStyle(fontSize: 12, color: MediCardColors.muted, height: 1.4)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _activity,
          decoration: const InputDecoration(
              labelText: 'Activity', hintText: 'e.g. Walk 20 minutes (comma separated)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _followUp,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Follow-up in (days)', hintText: 'e.g. 14'),
        ),
        if (_tests.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, children: [
              for (final t in _tests)
                InputChip(
                  label: Text('${t.name} in ${t.inDays} days'),
                  onDeleted: () => setState(() => _tests = _tests.where((x) => x != t).toList()),
                ),
            ]),
          ),
      ]),
    );
  }
}
