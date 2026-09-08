import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import 'models.dart';
import 'records_repository.dart';

class ExtractionReviewScreen extends ConsumerStatefulWidget {
  const ExtractionReviewScreen({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<ExtractionReviewScreen> createState() => _State();
}

class _State extends ConsumerState<ExtractionReviewScreen> {
  RecordData? _data;
  ExtractionView? _extraction;
  String _type = 'prescription';
  final _docDate = TextEditingController();
  final _provider = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _docDate.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final (ex, data) = await ref.read(recordsRepositoryProvider).extract(widget.recordId);
      setState(() {
        _extraction = ex;
        _data = data;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ?? 'Extraction failed';
        _loading = false;
      });
    }
  }

  bool _lowConfidence(String path) {
    final c = _extraction?.confidenceByField[path];
    return c != null && c < 0.7;
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recordsRepositoryProvider).confirm(
            recordId: widget.recordId,
            type: _type,
            docDate: _docDate.text.trim().isEmpty ? null : _docDate.text.trim(),
            provider: _provider.text.trim().isEmpty ? null : _provider.text.trim(),
            data: _data!,
          );
      ref.invalidate(recordsListProvider);
      if (mounted) context.pushReplacement('/patient/records/${widget.recordId}');
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
        title: const Text('Review & Confirm'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/patient/records'),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Reading the document...'),
                ]),
              ))
            : _data == null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'Nothing to review'),
                  ))
                : _form(),
      ),
    );
  }

  Widget _form() {
    final data = _data!;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: MediCardColors.unverified.withOpacity(0.12),
          padding: const EdgeInsets.all(12),
          child: const Text(
            'Nothing is saved yet. Fix anything the AI misread — fields flagged below '
            'were low-confidence — then confirm.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Record type'),
                items: const ['prescription', 'lab', 'imaging', 'note']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'note'),
              ),
              _plain(_docDate, 'Document date (YYYY-MM-DD)', flag: _lowConfidence('doc_date')),
              _plain(_provider, 'Provider / clinic', flag: _lowConfidence('provider')),
              const SizedBox(height: 8),
              _StringList(
                title: 'Diagnoses',
                values: data.diagnoses,
                onChanged: () => setState(() {}),
              ),
              _MedList(
                meds: data.medications,
                lowConfidence: _lowConfidence,
                onChanged: () => setState(() {}),
              ),
              _LabList(
                labs: data.labResults,
                lowConfidence: _lowConfidence,
                onChanged: () => setState(() {}),
              ),
              _StringList(
                title: 'Allergies',
                values: data.allergies,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: data.notes ?? '',
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                onChanged: (v) => data.notes = v.isEmpty ? null : v,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _confirm,
                child: Text(_saving ? 'Saving...' : 'Confirm & save as verified'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plain(TextEditingController c, String label, {bool flag = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
          if (flag) const _LowConfidenceChip(),
        ],
      ),
    );
  }
}

class _LowConfidenceChip extends StatelessWidget {
  const _LowConfidenceChip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(Icons.error_outline, size: 14, color: MediCardColors.unverified),
        SizedBox(width: 4),
        Text('Low confidence — please check',
            style: TextStyle(fontSize: 12, color: MediCardColors.unverified)),
      ]),
    );
  }
}

class _StringList extends StatelessWidget {
  const _StringList({required this.title, required this.values, required this.onChanged});

  final String title;
  final List<String> values;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  values.add('');
                  onChanged();
                },
              ),
            ]),
            for (var i = 0; i < values.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: values[i],
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) => values[i] = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      values.removeAt(i);
                      onChanged();
                    },
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedList extends StatelessWidget {
  const _MedList({required this.meds, required this.lowConfidence, required this.onChanged});

  final List<Medication> meds;
  final bool Function(String path) lowConfidence;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Medications', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  meds.add(Medication(name: ''));
                  onChanged();
                },
              ),
            ]),
            for (var i = 0; i < meds.length; i++) ...[
              if (i > 0) const Divider(),
              _field('Name', meds[i].name, (v) => meds[i].name = v,
                  flag: lowConfidence('data.medications[$i].name')),
              _field('Dose', meds[i].dose ?? '', (v) => meds[i].dose = v,
                  flag: lowConfidence('data.medications[$i].dose')),
              _field('Route', meds[i].route ?? '', (v) => meds[i].route = v),
              _field('Frequency', meds[i].freq ?? '', (v) => meds[i].freq = v,
                  flag: lowConfidence('data.medications[$i].freq')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    meds.removeAt(i);
                    onChanged();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabList extends StatelessWidget {
  const _LabList({required this.labs, required this.lowConfidence, required this.onChanged});

  final List<LabResult> labs;
  final bool Function(String path) lowConfidence;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Lab results', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  labs.add(LabResult(name: ''));
                  onChanged();
                },
              ),
            ]),
            for (var i = 0; i < labs.length; i++) ...[
              if (i > 0) const Divider(),
              _field('Name', labs[i].name, (v) => labs[i].name = v),
              _field('Value', labs[i].value ?? '', (v) => labs[i].value = v,
                  flag: lowConfidence('data.lab_results[$i].value')),
              _field('Unit', labs[i].unit ?? '', (v) => labs[i].unit = v),
              _field('Reference range', labs[i].refRange ?? '', (v) => labs[i].refRange = v),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    labs.removeAt(i);
                    onChanged();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _field(String label, String value, ValueChanged<String> onChanged, {bool flag = false}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: value,
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: onChanged,
        ),
        if (flag) const _LowConfidenceChip(),
      ],
    ),
  );
}
