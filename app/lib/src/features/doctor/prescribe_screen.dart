import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    this.origin = 'manual',
    this.fromCandidateId,
  });

  String name;
  String dose;
  String route;
  String freq;
  String origin; // manual | history
  String? fromCandidateId;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'dose': dose.trim().isEmpty ? null : dose.trim(),
        'route': route.trim().isEmpty ? null : route.trim(),
        'freq': freq.trim().isEmpty ? null : freq.trim(),
        'origin': origin,
      };
}

class PrescribeScreen extends ConsumerStatefulWidget {
  const PrescribeScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PrescribeScreen> createState() => _State();
}

class _State extends ConsumerState<PrescribeScreen> {
  RxContext? _ctx;
  final List<_Line> _draft = [];
  final _notes = TextEditingController();
  List<RxCheck> _checks = [];
  bool _loading = true;
  bool _saving = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  AccessRepository get _repo => ref.read(accessRepositoryProvider);

  Future<void> _load() async {
    try {
      final c = await _repo.prescribeContext(widget.patientId);
      setState(() {
        _ctx = c;
        _loading = false;
      });
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
}
