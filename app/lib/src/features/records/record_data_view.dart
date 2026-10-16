import 'package:flutter/material.dart';

import '../../theme.dart';
import 'models.dart';

/// Read-only render of a record's structured fields, as clean cards.
/// Shared by the patient and doctor record-detail screens.
class RecordDataView extends StatelessWidget {
  const RecordDataView({super.key, required this.data});

  final RecordData data;

  static String _flag(String? value, String? ref) {
    final x = double.tryParse((value ?? '').replaceAll(',', '').trim());
    if (x == null || ref == null) return 'unknown';
    final r = ref.replaceAll('–', '-').trim();
    final lt = RegExp(r'^<\s*=?\s*([\d.]+)$').firstMatch(r);
    if (lt != null) return x > double.parse(lt.group(1)!) ? 'high' : 'normal';
    final gt = RegExp(r'^>\s*=?\s*([\d.]+)$').firstMatch(r);
    if (gt != null) return x < double.parse(gt.group(1)!) ? 'low' : 'normal';
    final rg = RegExp(r'^([\d.]+)\s*-\s*([\d.]+)$').firstMatch(r);
    if (rg != null) {
      return x < double.parse(rg.group(1)!)
          ? 'low'
          : x > double.parse(rg.group(2)!)
              ? 'high'
              : 'normal';
    }
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final empty = data.diagnoses.isEmpty &&
        data.medications.isEmpty &&
        data.labResults.isEmpty &&
        data.allergies.isEmpty &&
        (data.notes == null || data.notes!.isEmpty);
    if (empty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No details were recorded.', style: TextStyle(color: MediCardColors.muted)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data.diagnoses.isNotEmpty)
        _Block('Diagnoses', Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in data.diagnoses)
            _Chip(d, const Color(0xFFEEF2FF), const Color(0xFF3730A3)),
        ])),
      if (data.medications.isNotEmpty)
        _Block('Medications', Column(children: [
          for (final m in data.medications)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MediCardColors.border),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.medication_outlined, color: Color(0xFF6D28D9), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      [m.name, m.dose].where((e) => e != null && e.isNotEmpty).join(' '),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    Text(
                      [m.freq, m.route].where((e) => e != null && e.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 12.5, color: MediCardColors.muted),
                    ),
                  ]),
                ),
              ]),
            ),
        ])),
      if (data.labResults.isNotEmpty)
        _Block('Lab results', Column(children: [
          for (var i = 0; i < data.labResults.length; i++) _labRow(data.labResults[i], i),
        ])),
      if (data.allergies.isNotEmpty)
        _Block('Allergies', Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in data.allergies)
            _Chip('⚠ $a', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
        ])),
      if (data.notes != null && data.notes!.isNotEmpty)
        _Block(
            'Notes',
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
              child: Text(data.notes!, style: const TextStyle(fontSize: 14, height: 1.5)),
            )),
    ]);
  }

  Widget _labRow(LabResult l, int i) {
    final f = _flag(l.value, l.refRange);
    final (label, color) = switch (f) {
      'high' => ('High', MediCardColors.danger),
      'low' => ('Low', MediCardColors.warning),
      'normal' => ('Normal', MediCardColors.verified),
      _ => ('', MediCardColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : MediCardColors.border))),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (l.refRange != null && l.refRange!.isNotEmpty)
              Text('Normal: ${l.refRange}',
                  style: const TextStyle(fontSize: 11.5, color: MediCardColors.muted)),
          ]),
        ),
        Expanded(
          flex: 4,
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: l.value ?? '?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
            TextSpan(
                text: ' ${l.unit ?? ''}',
                style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
          ])),
        ),
        if (label.isNotEmpty)
          Container(
            width: 62,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration:
                BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
            child: Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5, color: MediCardColors.muted)),
          const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
