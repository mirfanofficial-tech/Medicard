import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../demo/demo_data.dart' show demoQuestions;
import '../../theme.dart';
import '../access/access_repository.dart';
import '../access/models.dart';
import 'patient_records_screen.dart' show doctorRecordsProvider;

class AiPanelScreen extends ConsumerStatefulWidget {
  const AiPanelScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<AiPanelScreen> createState() => _State();
}

class _State extends ConsumerState<AiPanelScreen> {
  final _q = TextEditingController();
  AiAnswer? _answer;
  bool _asking = false;
  String? _askError;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _q.text.trim();
    if (question.length < 3) return;
    setState(() {
      _asking = true;
      _askError = null;
    });
    try {
      final a = await ref.read(accessRepositoryProvider).aiAsk(widget.patientId, question);
      setState(() => _answer = a);
    } on DioException catch (e) {
      setState(() => _askError = e.response?.data?['detail']?.toString() ?? 'Ask failed');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _openRecord(String recordId) =>
      context.go('/doctor/patients/${widget.patientId}/records/$recordId');

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(aiSummaryProvider(widget.patientId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI summary'),
        leading: BackButton(
          onPressed: () => context.go('/doctor/patients/${widget.patientId}/records'),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: MediCardColors.seed.withOpacity(0.10),
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Advisory only — decision support, not a diagnosis or prescription. '
              'You retain full clinical and prescribing responsibility.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Center(
             child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                summary.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Could not load summary: $e'),
                  data: (s) => _summaryView(s),
                ),
                const Divider(height: 32),
                Text('Ask about this record', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text('Tap a question to try it, or type your own.',
                    style: TextStyle(fontSize: 12.5, color: MediCardColors.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final q in demoQuestions)
                    ActionChip(
                      label: Text(q),
                      onPressed: _asking
                          ? null
                          : () {
                              _q.text = q;
                              _ask();
                            },
                      backgroundColor: MediCardColors.primaryTint,
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                          color: Color(0xFF0A5D57), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Any documented penicillin allergy?',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _ask(),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _asking ? null : _ask,
                  child: Text(_asking ? 'Asking...' : 'Ask'),
                ),
                if (_askError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_askError!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_answer != null) _answerView(_answer!),
              ],
            ),
          ))),
        ],
      ),
    );
  }

  Widget _summaryView(AiSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.summary),
        if (s.model == 'stub')
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('(stub — no model configured)',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        const SizedBox(height: 12),
        for (final f in s.flags) _flagCard(f),
        if (s.relevantHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Relevant history', style: Theme.of(context).textTheme.titleSmall),
          for (final h in s.relevantHistory) Text('• $h'),
        ],
      ],
    );
  }

  Widget _flagCard(AiFlag f) {
    final color = switch (f.severity) {
      'urgent' => MediCardColors.danger,
      'watch' => MediCardColors.unverified,
      _ => MediCardColors.seed,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag, size: 16, color: color),
              const SizedBox(width: 6),
              Text(f.severity.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(f.text),
            const SizedBox(height: 6),
            _sourceChips(f.sourceRecordIds),
          ],
        ),
      ),
    );
  }

  Widget _answerView(AiAnswer a) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: a.answeredFromRecords
            ? null
            : MediCardColors.unverified.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.answer),
              const SizedBox(height: 6),
              if (a.answeredFromRecords)
                _sourceChips(a.sourceRecordIds)
              else
                const Text('Not answered from this patient\'s records.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  /// "Lab · 12 Oct" when the record list is loaded, otherwise a short id.
  String _label(String id) {
    final rows = ref.watch(doctorRecordsProvider(widget.patientId)).valueOrNull;
    final r = rows?.where((x) => x.id == id).firstOrNull;
    if (r == null) return 'record ${id.length > 8 ? id.substring(0, 8) : id}';
    final kind = switch (r.type) {
      'lab' => 'Lab',
      'prescription' => 'Prescription',
      'imaging' => 'Imaging',
      _ => 'Note',
    };
    final d = DateTime.tryParse(r.docDate ?? '');
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return d == null ? kind : '$kind · ${d.day} ${m[d.month - 1]}';
  }

  Widget _sourceChips(List<String> ids) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final id in ids)
          ActionChip(
            label: Text(_label(id), style: const TextStyle(fontSize: 11)),
            onPressed: () => _openRecord(id),
          ),
      ],
    );
  }
}
