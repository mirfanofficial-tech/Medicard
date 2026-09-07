import 'package:flutter/material.dart';

import 'models.dart';

/// Read-only render of a record's structured fields. Shared by the patient and
/// doctor record-detail screens.
class RecordDataView extends StatelessWidget {
  const RecordDataView({super.key, required this.data});

  final RecordData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bullets('Diagnoses', data.diagnoses),
        if (data.medications.isNotEmpty) ...[
          const _Heading('Medications'),
          for (final m in data.medications)
            Text('• ${m.name}'
                '${m.dose != null && m.dose!.isNotEmpty ? ', ${m.dose}' : ''}'
                '${m.freq != null && m.freq!.isNotEmpty ? ', ${m.freq}' : ''}'
                '${m.route != null && m.route!.isNotEmpty ? ' (${m.route})' : ''}'),
          const SizedBox(height: 12),
        ],
        if (data.labResults.isNotEmpty) ...[
          const _Heading('Lab results'),
          for (final l in data.labResults)
            Text('• ${l.name}: ${l.value ?? '?'}'
                '${l.unit != null && l.unit!.isNotEmpty ? ' ${l.unit}' : ''}'
                '${l.refRange != null && l.refRange!.isNotEmpty ? ' (ref ${l.refRange})' : ''}'),
          const SizedBox(height: 12),
        ],
        _bullets('Allergies', data.allergies),
        if (data.notes != null && data.notes!.isNotEmpty) ...[
          const _Heading('Notes'),
          Text(data.notes!),
        ],
      ],
    );
  }

  Widget _bullets(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title),
        for (final i in items) Text('• $i'),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
