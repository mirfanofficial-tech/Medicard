import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import 'models.dart';
import 'records_repository.dart';

final _recordProvider =
    FutureProvider.autoDispose.family<RecordDetail, String>((ref, id) {
  return ref.watch(recordsRepositoryProvider).get(id);
});

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_recordProvider(recordId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record'),
        leading: BackButton(onPressed: () => context.go('/patient/records')),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (d) => _body(context, ref, d),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, RecordDetail d) {
    final data = d.data;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text(d.summary.type.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          ProvenanceTag(verified: d.summary.verified),
        ]),
        if (!d.summary.verified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              color: MediCardColors.unverified.withOpacity(0.12),
              child: Row(children: [
                const Expanded(
                  child: Text('This record has not been confirmed yet.',
                      style: TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => context.go('/patient/records/$recordId/review'),
                  child: const Text('Review'),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('${d.summary.docDate ?? 'Undated'}'
            '${d.summary.provider != null ? ' · ${d.summary.provider}' : ''}'),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hidden by default'),
          subtitle: const Text('Requires an extra tap for anyone viewing your record'),
          value: d.summary.sensitive,
          onChanged: (v) async {
            await ref.read(recordsRepositoryProvider).setSensitive(recordId, v);
            ref.invalidate(_recordProvider(recordId));
            ref.invalidate(recordsListProvider);
          },
        ),
        const Divider(height: 24),
        _list('Diagnoses', data.diagnoses),
        _meds(context, data.medications),
        _labs(context, data.labResults),
        _list('Allergies', data.allergies),
        if (data.notes != null && data.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Notes', style: Theme.of(context).textTheme.titleSmall),
          Text(data.notes!),
        ],
        if (d.sourceUrl != null) ...[
          const SizedBox(height: 16),
          Text('Source', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(d.sourceUrl!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _list(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final i in items) Text('• $i'),
        ],
      ),
    );
  }

  Widget _meds(BuildContext context, List<Medication> meds) {
    if (meds.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Medications', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final m in meds)
            Text('• ${m.name}'
                '${m.dose != null ? ', ${m.dose}' : ''}'
                '${m.freq != null ? ', ${m.freq}' : ''}'
                '${m.route != null ? ' (${m.route})' : ''}'),
        ],
      ),
    );
  }

  Widget _labs(BuildContext context, List<LabResult> labs) {
    if (labs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lab results', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final l in labs)
            Text('• ${l.name}: ${l.value ?? '?'}'
                '${l.unit != null ? ' ${l.unit}' : ''}'
                '${l.refRange != null ? ' (ref ${l.refRange})' : ''}'),
        ],
      ),
    );
  }
}
