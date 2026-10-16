import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env.dart';
import '../../core/language.dart';
import '../../demo/demo_data.dart' show demoDictation;
import '../../core/voice_input.dart';
import '../../theme.dart';
import '../access/access_repository.dart';
import '../care/care_models.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_panel.dart';
import '../../demo/demo_data.dart' show demoQuestions;
import '../records/models.dart';
import 'doctor_top_bar.dart';

final doctorRecordsProvider = FutureProvider.autoDispose
    .family<List<RecordSummary>, String>((ref, pid) {
  return ref.watch(accessRepositoryProvider).patientRecords(pid);
});

/// The doctor's one-page patient dashboard: who the patient is, what matters
/// in their history, results, documents, AI insights and what the doctor did.
class DoctorPatientRecordsScreen extends ConsumerWidget {
  const DoctorPatientRecordsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ov = ref.watch(patientOverviewDataProvider(patientId));
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1100;
          final pad = c.maxWidth >= 700 ? 28.0 : 14.0;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(patientOverviewDataProvider(patientId).future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    DoctorTopBar(showBack: true, patientId: patientId),
                    const SizedBox(height: 18),
                    ov.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text('Could not load this patient.\n$e'),
                      ),
                      data: (o) => _body(context, ref, o, wide),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PatientOverviewData o, bool wide) {
    final left = <Widget>[
      _PatientCard(o: o, patientId: patientId),
      const SizedBox(height: 16),
      _StatStrip(o.counts),
      const SizedBox(height: 16),
      _TimelineAndLabs(o: o, patientId: patientId),
      const SizedBox(height: 16),
      if (o.trends.isNotEmpty) ...[_Trends(o.trends), const SizedBox(height: 16)],
      _DocsRow(o: o, patientId: patientId),
      const SizedBox(height: 16),
    ];
    final right = <Widget>[
      _QuickSummary(o),
      const SizedBox(height: 16),
      ChatPanel(
        scope: ChatScope.doctor(patientId: patientId),
        title: 'Ask about ${o.name.split(' ').first}',
        subtitle: 'AI assistant · answers from her shared records',
        welcome: "I can answer from ${o.name.split(' ').first}'s shared records and show the "
            'source of every answer. The clinical decision is always yours.',
        suggestions: demoQuestions,
        accent: doctorAccent,
        height: 580,
        onSourceTap: (id) => context.go('/doctor/patients/$patientId/records/$id'),
      ),
      const SizedBox(height: 16),
      _AiInsights(patientId: patientId),
      const SizedBox(height: 16),
      _VoiceNote(patientId: patientId),
      const SizedBox(height: 16),
      _HistoryPanel(alerts: o.alerts, patientId: patientId),
      const SizedBox(height: 16),
      _Card(
        title: 'Worth a look today',
        subtitle: 'Small suggestions from the records — you decide',
        child: o.tips.isEmpty
            ? const Text('Nothing flagged.', style: TextStyle(color: MediCardColors.muted))
            : Column(children: [
                for (final t in o.tips)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: _sev(t.severity)),
                      ),
                      Expanded(
                          child: Text(t.text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                    ]),
                  ),
              ]),
      ),
      const SizedBox(height: 16),
      if (o.adherence.isNotEmpty) ...[
        _Card(
          title: 'Following the plan?',
          subtitle: 'Patient\'s last 7 days',
          child: Column(children: [for (final a in o.adherence) _AdherenceBar(a)]),
        ),
        const SizedBox(height: 16),
      ],
      const _PendingAndLog(),
      const SizedBox(height: 14),
      Text(o.notice,
          style: const TextStyle(fontSize: 11.5, color: MediCardColors.muted, height: 1.4)),
    ];
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 7, child: Column(children: left)),
        const SizedBox(width: 20),
        Expanded(flex: 4, child: Column(children: right)),
      ]);
    }
    return Column(children: [...left, ...right]);
  }
}

Color _sev(String s) => switch (s) {
      'urgent' => MediCardColors.danger,
      'watch' => MediCardColors.warning,
      _ => MediCardColors.primary,
    };

class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
            ),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12.5)),
      );
}

/// Voice note: speak, see the visit note written, hand the dictation to Prescribe.
class _VoiceNote extends ConsumerStatefulWidget {
  const _VoiceNote({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends ConsumerState<_VoiceNote> {
  final _voice = VoiceInput();
  final _text = TextEditingController();
  VoiceDraft? _draft;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _voice.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _voice.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    if (_text.text.trim().length < 3) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ref.read(accessRepositoryProvider).voiceParse(_text.text.trim());
      if (mounted) setState(() => _draft = d);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not write the note. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mic() async {
    if (_voice.listening) {
      await _voice.stop();
      await _parse();
      return;
    }
    await _voice.start(
      urdu: ref.read(urduProvider),
      onText: (t, _) => _text.text = t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final urdu = ref.watch(urduProvider);
    final listening = _voice.listening;
    final d = _draft;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MediCardColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
            onTap: _mic,
            customBorder: const CircleBorder(),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening ? MediCardColors.danger : MediCardColors.primary,
                boxShadow: [
                  BoxShadow(
                      color: (listening ? MediCardColors.danger : MediCardColors.primary)
                          .withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(listening ? Icons.stop : Icons.mic, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listening ? 'Listening… speak your visit note' : 'Tap and speak your visit note',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(urdu ? 'Urdu' : 'English',
                  style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
            ]),
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('EN')),
              ButtonSegment(value: true, label: Text('اردو')),
            ],
            selected: {urdu},
            onSelectionChanged: (s) => ref.read(urduProvider.notifier).state = s.first,
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Speak, or type here: “Patient reports tiredness and thirst for two weeks…”',
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
              onPressed: () => setState(() => _text.text = demoDictation),
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [
          FilledButton(
            onPressed: _busy ? null : _parse,
            style: FilledButton.styleFrom(minimumSize: const Size(160, 46)),
            child: Text(_busy ? 'Writing…' : 'Write it for me'),
          ),
          const SizedBox(width: 10),
          if (d != null)
            OutlinedButton(
              onPressed: () => context.go(
                '/doctor/patients/${widget.patientId}/prescribe',
                extra: _text.text.trim(),
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('Use in prescription'),
            ),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: MediCardColors.danger)),
          ),
        if (d != null) ...[
          const SizedBox(height: 14),
          for (final (k, v) in [
            ('Complaint', d.complaint),
            ('Assessment', d.assessment),
            ('Plan', d.plan),
          ])
            if (v != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: MediCardColors.bg, borderRadius: BorderRadius.circular(10)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$k · ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Color(0xFF0A5D57))),
                  TextSpan(text: v),
                ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
              ),
          const Text('Written from your words. Check it — nothing is saved from here.',
              style: TextStyle(fontSize: 11.5, color: MediCardColors.muted)),
        ],
      ]),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.alerts, required this.patientId});
  final List<HistoryAlert> alerts;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MediCardColors.primary, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: MediCardColors.primaryTint, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.history, color: MediCardColors.primary),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Before you prescribe — from this patient\'s history',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              Text('Important past events, surfaced for you. Each links to the original record.',
                  style: TextStyle(fontSize: 12, color: MediCardColors.muted)),
            ]),
          ),
          const StatusPill(label: 'Advisory', color: MediCardColors.unverified),
        ]),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          const Text('No allergies, past reactions or stopped medicines are on record.',
              style: TextStyle(color: MediCardColors.muted))
        else
          for (final a in alerts)
            InkWell(
              onTap: () => context.go('/doctor/patients/$patientId/records/${a.sourceRecordId}'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _sev(a.severity).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _sev(a.severity).withOpacity(0.35)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 112,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      switch (a.kind) {
                        'allergy' => 'ALLERGY',
                        'reaction' => 'PAST MED EFFECT',
                        _ => 'STOPPED',
                      },
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _sev(a.severity)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(a.text, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: MediCardColors.primaryTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(a.sourceLabel,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A5D57))),
                  ),
                ]),
              ),
            ),
      ]),
    );
  }
}

class _Trends extends StatelessWidget {
  const _Trends(this.trends);
  final List<TrendData> trends;

  @override
  Widget build(BuildContext context) => _Card(
        title: 'Lab trends',
        child: LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 560;
          final tiles = [for (final t in trends) _TrendTile(t)];
          return narrow
              ? Column(children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 10), child: t)])
              : Row(children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: tiles[i]),
                  ],
                ]);
        }),
      );
}

class _TrendTile extends StatelessWidget {
  const _TrendTile(this.t);
  final TrendData t;

  @override
  Widget build(BuildContext context) {
    final color = switch (t.flag) {
      'high' || 'low' => MediCardColors.danger,
      'normal' => MediCardColors.verified,
      _ => MediCardColors.muted,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), border: Border.all(color: MediCardColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(t.flag.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 2),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: t.latest.abs() < 10 || t.latest != t.latest.roundToDouble()
                  ? t.latest.toStringAsFixed(1)
                  : t.latest.toStringAsFixed(0),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          TextSpan(
              text: ' ${t.unit ?? ''}',
              style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
        ])),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: CustomPaint(painter: _SparkPainter(t.values, color)),
        ),
      ]),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 4 - (size.height - 8) * ((values[i] - lo) / span);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}

class _AdherenceBar extends StatelessWidget {
  const _AdherenceBar(this.a);
  final AdherenceRow a;

  @override
  Widget build(BuildContext context) {
    final p = a.total == 0 ? 0.0 : a.done / a.total;
    final color = p >= 0.8
        ? MediCardColors.verified
        : p >= 0.5
            ? MediCardColors.warning
            : MediCardColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Text('${a.done} of ${a.total}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
              value: p, minHeight: 8, backgroundColor: MediCardColors.border, color: color),
        ),
      ]),
    );
  }
}


String _initials(String name) =>
    name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.o, required this.patientId});
  final PatientOverviewData o;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final facts = <Widget>[
      if (o.age != null) _Fact('Age: ${o.age} Years'),
      if (o.gender != null) _Fact(o.gender!),
      if (o.bloodGroup != null) _Fact('Blood Group: ${o.bloodGroup}', color: MediCardColors.danger),
      if (o.phone != null) _Fact(o.phone!, icon: Icons.phone_outlined),
    ];
    final left = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [MediCardColors.primaryDark, MediCardColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Text(_initials(o.name),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(o.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified, color: Color(0xFF2563EB), size: 22),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: Text('Patient ID:  ${o.code}',
                  style: const TextStyle(color: MediCardColors.muted, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy ID',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: o.code));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Patient ID copied')));
              },
              icon: const Icon(Icons.copy, size: 16, color: MediCardColors.muted),
            ),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 14, runSpacing: 6, children: facts),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in o.conditions)
              _Chip(c, const Color(0xFFEEF2FF), const Color(0xFF3730A3)),
            if (o.allergies.isEmpty)
              const _Chip('No Known Allergies', Color(0xFFEEF2FF), Color(0xFF3730A3))
            else
              for (final a in o.allergies)
                _Chip('⚠ Allergy: $a', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => context.go('/doctor/patients/$patientId/prescribe'),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Prescribe'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/doctor/patients/$patientId/ai'),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('AI summary'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ]),
        ]),
      ),
    ]);

    final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SideFact(Icons.calendar_month_outlined, 'Registered On', o.registeredOn ?? '—'),
      const SizedBox(height: 12),
      _SideFact(Icons.history_toggle_off, 'Last Updated', o.lastUpdated ?? '—'),
      const SizedBox(height: 14),
      OutlinedButton(
        onPressed: () => context.go('/doctor/patients/$patientId/critical'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(190, 44)),
        child: const Text('View Full Profile'),
      ),
    ]);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panel(),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            Container(
                width: 1,
                height: 150,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                color: MediCardColors.border),
            SizedBox(width: 200, child: right),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          left,
          const SizedBox(height: 16),
          right,
        ]);
      }),
    );
  }
}

BoxDecoration _panel({Color? color, Color? border}) => BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border ?? MediCardColors.border),
      boxShadow: [
        BoxShadow(color: MediCardColors.ink.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 6)),
      ],
    );

class _Fact extends StatelessWidget {
  const _Fact(this.text, {this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: MediCardColors.primary), const SizedBox(width: 5)],
        Text(text,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: color ?? const Color(0xFF475569))),
      ]);
}

class _SideFact extends StatelessWidget {
  const _SideFact(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text(value, style: const TextStyle(color: MediCardColors.muted, fontSize: 13)),
          ]),
        ),
      ]);
}

class _QuickSummary extends StatelessWidget {
  const _QuickSummary(this.o);
  final PatientOverviewData o;

  @override
  Widget build(BuildContext context) {
    final raw = o.visits.isEmpty ? null : o.visits.first.split(' · ').first;
    final d = raw == null ? null : DateTime.tryParse(raw);
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final last = d == null ? raw : '${d.day} ${mo[d.month - 1]} ${d.year}';
    Widget row(String n, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
                width: 22,
                child: Text(n,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Expanded(
              child: Text(t, style: const TextStyle(fontSize: 14.5, color: Color(0xFF334155))),
            ),
          ]),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _panel(color: const Color(0xFFF0FBF7), border: const Color(0xFFCDEFE3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.description_outlined, color: MediCardColors.primary, size: 28),
          SizedBox(width: 12),
          Text('Quick Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        row('${o.counts.conditions}', 'Current Conditions'),
        row('${o.counts.medications}', 'Current Medications'),
        row(o.upcoming == null ? '0' : '1', o.upcoming == null ? 'Upcoming Appointments' : 'Upcoming: ${o.upcoming}'),
        if (last != null && last.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Last checkup: $last',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
          ),
      ]),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip(this.c);
  final OverviewCountsData c;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.monitor_heart_outlined, 'Conditions', c.conditions, const Color(0xFF6366F1)),
      (Icons.medication_outlined, 'Medications', c.medications, const Color(0xFF10B981)),
      (Icons.warning_amber_rounded, 'Allergies', c.allergies, MediCardColors.danger),
      (Icons.description_outlined, 'Documents', c.documents, const Color(0xFF2563EB)),
      (Icons.science_outlined, 'Lab Tests', c.labTests, const Color(0xFF7C3AED)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: _panel(),
      child: Wrap(alignment: WrapAlignment.spaceEvenly, runSpacing: 14, spacing: 10, children: [
        for (final i in items)
          SizedBox(
            width: 150,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i.$1, color: i.$4, size: 30),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: MediCardColors.muted)),
                  Text('${i.$3}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _TimelineAndLabs extends StatelessWidget {
  const _TimelineAndLabs({required this.o, required this.patientId});
  final PatientOverviewData o;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final timeline = _Timeline(o: o, patientId: patientId);
    final labs = _LabsCard(o: o, patientId: patientId);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 760) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: timeline),
          const SizedBox(width: 16),
          Expanded(child: labs),
        ]);
      }
      return Column(children: [timeline, const SizedBox(height: 16), labs]);
    });
  }
}

({IconData icon, Color color, String label}) _typeStyle(String type) => switch (type) {
      'lab' => (icon: Icons.science, color: const Color(0xFF16A34A), label: 'Lab Report'),
      'prescription' => (icon: Icons.medication, color: const Color(0xFFF59E0B), label: 'Prescription'),
      'imaging' => (icon: Icons.photo_camera, color: const Color(0xFF2563EB), label: 'Imaging'),
      _ => (icon: Icons.medical_services, color: const Color(0xFF8B5CF6), label: 'Clinic Visit'),
    };

class _Timeline extends StatefulWidget {
  const _Timeline({required this.o, required this.patientId});
  final PatientOverviewData o;
  final String patientId;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final rows = _all ? widget.o.records : widget.o.records.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.timeline, color: MediCardColors.primary, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text('Medical History Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const Text('No shared records.', style: TextStyle(color: MediCardColors.muted)),
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: () => context
                .go('/doctor/patients/${widget.patientId}/records/${rows[i].recordId}'),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _typeStyle(rows[i].type).color,
                    child: Icon(_typeStyle(rows[i].type).icon, color: Colors.white, size: 19),
                  ),
                  if (i < rows.length - 1)
                    Expanded(child: Container(width: 2, color: MediCardColors.border)),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${rows[i].date ?? ''}  •  ',
                            style: const TextStyle(color: MediCardColors.muted)),
                        TextSpan(
                            text: _typeStyle(rows[i].type).label,
                            style: const TextStyle(
                                color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                      ]), style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Expanded(
                          child: Text(rows[i].title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        ),
                        if ((rows[i].summary ?? '').contains('(High)'))
                          const StatusPill(label: 'High', color: MediCardColors.danger),
                      ]),
                      if (rows[i].summary != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(rows[i].summary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        if (widget.o.records.length > 4)
          OutlinedButton(
            onPressed: () => setState(() => _all = !_all),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(_all ? 'Show less' : 'View Full Timeline'),
          ),
      ]),
    );
  }
}

class _LabsCard extends StatelessWidget {
  const _LabsCard({required this.o, required this.patientId});
  final PatientOverviewData o;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.science_outlined, color: MediCardColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Latest Lab Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        if (o.labs.isEmpty)
          const Text('No lab results shared.', style: TextStyle(color: MediCardColors.muted)),
        for (var i = 0; i < o.labs.length; i++)
          InkWell(
            onTap: () =>
                context.go('/doctor/patients/$patientId/records/${o.labs[i].recordId}'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: i == 0 ? Colors.transparent : MediCardColors.border))),
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.labs[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(o.labs[i].date ?? '',
                        style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                  ]),
                ),
                Expanded(
                  flex: 4,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: o.labs[i].value,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    TextSpan(
                        text: ' ${o.labs[i].unit ?? ''}',
                        style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                  ])),
                ),
                _FlagPill(o.labs[i].flag),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _FlagPill extends StatelessWidget {
  const _FlagPill(this.flag);
  final String flag;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (flag) {
      'high' => ('High', MediCardColors.danger),
      'low' => ('Low', MediCardColors.warning),
      'normal' => ('Normal', MediCardColors.verified),
      _ => ('—', MediCardColors.muted),
    };
    return Container(
      width: 62,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _DocsRow extends StatelessWidget {
  const _DocsRow({required this.o, required this.patientId});
  final PatientOverviewData o;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final docs = o.records.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.folder_open, color: MediCardColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Recent Documents & Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        if (docs.isEmpty)
          const Text('No documents shared.', style: TextStyle(color: MediCardColors.muted)),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final d in docs)
            InkWell(
              onTap: () => context.go('/doctor/patients/$patientId/records/${d.recordId}'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MediCardColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 70,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _typeStyle(d.type).color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeStyle(d.type).icon, color: _typeStyle(d.type).color, size: 30),
                  ),
                  const SizedBox(height: 8),
                  Text(d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(
                      child: Text(d.date ?? '',
                          style: const TextStyle(fontSize: 11.5, color: MediCardColors.muted)),
                    ),
                    if (d.verified)
                      const Icon(Icons.check_circle, size: 15, color: MediCardColors.success),
                  ]),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _AiInsights extends ConsumerWidget {
  const _AiInsights({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiSummaryProvider(patientId));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: Color(0xFF6D28D9), size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text('AI Health Insights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4C1D95))),
          ),
          StatusPill(label: 'Advisory Only', color: Color(0xFF6D28D9)),
        ]),
        const SizedBox(height: 12),
        ai.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const Text('Insights are not available right now.',
              style: TextStyle(color: MediCardColors.muted)),
          data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s.flags.isEmpty)
              Text(s.summary, style: const TextStyle(fontSize: 13.5, height: 1.5)),
            for (final f in s.flags.take(3))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _sev(f.severity).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _sev(f.severity).withOpacity(0.25)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(f.severity == 'urgent' ? Icons.warning_amber_rounded : Icons.trending_up,
                      color: _sev(f.severity), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.text, style: const TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Source: ${f.sourceRecordIds.length} record(s)',
                          style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                    ]),
                  ),
                ]),
              ),
            const Text('AI provides insights based on available data. Physician review required.',
                style: TextStyle(fontSize: 12, color: MediCardColors.muted, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.go('/doctor/patients/$patientId/ai'),
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5B3FD0), minimumSize: const Size.fromHeight(48)),
          child: const Text('View All Insights'),
        ),
      ]),
    );
  }
}

/// "Pending access requests" and "Recent access log" from the doctor's dashboard data.
class _PendingAndLog extends ConsumerWidget {
  const _PendingAndLog();

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(doctorDashboardProvider);
    return dash.maybeWhen(
      data: (d) => Column(children: [
        _Card(
          title: 'Pending Access Requests',
          child: d.pending.isEmpty
              ? const Text('No requests waiting.', style: TextStyle(color: MediCardColors.muted))
              : Column(children: [
                  for (final p in d.pending)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFFEF3C7),
                          child: Text(_initials(p.name),
                              style: const TextStyle(
                                  color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('Asked ${_ago(p.createdAt)}',
                                style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                          ]),
                        ),
                        const StatusPill(label: 'Waiting', color: MediCardColors.unverified),
                      ]),
                    ),
                ]),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Recent Access Log',
          child: d.activity.isEmpty
              ? const Text('Nothing yet.', style: TextStyle(color: MediCardColors.muted))
              : Column(children: [
                  for (final a in d.activity.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: MediCardColors.primaryTint,
                          child: Text(_initials(a.name),
                              style: const TextStyle(
                                  color: MediCardColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.text,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${a.name} · ${_ago(a.at)}',
                                style: const TextStyle(fontSize: 11.5, color: MediCardColors.muted)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
        ),
      ]),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
