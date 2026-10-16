import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';
import '../patient/record_type_ui.dart';
import 'models.dart';
import 'record_data_view.dart';
import 'records_repository.dart';
import 'source_image.dart';

final _recordProvider =
    FutureProvider.autoDispose.family<RecordDetail, String>((ref, id) {
  return ref.watch(recordsRepositoryProvider).get(id);
});

enum LabBand { normal, low, high, unknown }

LabBand classifyLab(LabResult l) {
  final v = double.tryParse((l.value ?? '').replaceAll(RegExp('[^0-9.\\-]'), ''));
  final r = (l.refRange ?? '').trim();
  if (v == null || r.isEmpty) return LabBand.unknown;
  final lt = RegExp(r'^[<≤]\s*([0-9.]+)$').firstMatch(r);
  if (lt != null) return v <= double.parse(lt.group(1)!) ? LabBand.normal : LabBand.high;
  final gt = RegExp(r'^[>≥]\s*([0-9.]+)$').firstMatch(r);
  if (gt != null) return v >= double.parse(gt.group(1)!) ? LabBand.normal : LabBand.low;
  final range = RegExp(r'^([0-9.]+)\s*[-–]\s*([0-9.]+)$').firstMatch(r);
  if (range != null) {
    final lo = double.parse(range.group(1)!), hi = double.parse(range.group(2)!);
    if (v < lo) return LabBand.low;
    if (v > hi) return LabBand.high;
    return LabBand.normal;
  }
  return LabBand.unknown;
}

(String, Color) _bandUi(LabBand b) => switch (b) {
      LabBand.normal => ('Normal', MediCardColors.success),
      LabBand.low => ('Low', MediCardColors.warning),
      LabBand.high => ('High', MediCardColors.danger),
      LabBand.unknown => ('—', MediCardColors.muted),
    };

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_recordProvider(recordId));
    return Scaffold(
      appBar: AppBar(title: const Text('Record Details')),
      body: detail.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorBlock(e),
        data: (d) => _body(context, ref, d),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, RecordDetail d) {
    final ui = recordTypeUi(d.summary.type);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: MediCardColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: ui.color.withOpacity(0.12),
                    child: Icon(ui.icon, color: ui.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ui.label,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          [d.summary.docDate == null ? null : prettyDate(d.summary.docDate), d.summary.provider]
                              .where((e) => e != null)
                              .join(' · '),
                          style: const TextStyle(fontSize: 12, color: MediCardColors.muted),
                        ),
                      ],
                    ),
                  ),
                  ProvenanceTag(verified: d.summary.verified),
                ]),
                if (!d.summary.verified)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: InfoBanner(
                      'This record is not confirmed yet.',
                      color: MediCardColors.unverified,
                      icon: Icons.error_outline,
                    ),
                  ),
              ],
            ),
          ),
          const TabBar(
            labelColor: MediCardColors.primary,
            tabs: [Tab(text: 'Summary'), Tab(text: 'Details'), Tab(text: 'Documents')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _summaryTab(context, d),
                _detailsTab(context, ref, d),
                _documentsTab(d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTab(BuildContext context, RecordDetail d) {
    final labs = d.data.labResults;
    final bands = labs.map(classifyLab).toList();
    final counts = {
      LabBand.normal: bands.where((b) => b == LabBand.normal).length,
      LabBand.low: bands.where((b) => b == LabBand.low).length,
      LabBand.high: bands.where((b) => b == LabBand.high).length,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (labs.isNotEmpty) ...[
          Row(children: [
            _countPill('Normal', counts[LabBand.normal]!, MediCardColors.success),
            const SizedBox(width: 8),
            _countPill('Low', counts[LabBand.low]!, MediCardColors.warning),
            const SizedBox(width: 8),
            _countPill('High', counts[LabBand.high]!, MediCardColors.danger),
          ]),
          const SizedBox(height: 14),
          const SectionHeader('Key Results'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < labs.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _labRow(labs[i], bands[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (d.data.diagnoses.isNotEmpty) ...[
          const SectionHeader('Diagnoses'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final x in d.data.diagnoses) Text('• $x')],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (d.data.notes != null && d.data.notes!.isNotEmpty) ...[
          const SectionHeader('Notes'),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(d.data.notes!))),
        ],
        if (labs.isEmpty && d.data.diagnoses.isEmpty && (d.data.notes ?? '').isEmpty)
          const EmptyState(icon: Icons.summarize_outlined, title: 'Nothing to summarise'),
      ],
    );
  }

  Widget _labRow(LabResult l, LabBand band) {
    final (label, color) = _bandUi(band);
    return ListTile(
      dense: true,
      title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: l.refRange == null ? null : Text('ref ${l.refRange}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${l.value ?? '?'}${l.unit != null ? ' ${l.unit}' : ''}'),
          const SizedBox(width: 8),
          if (band != LabBand.unknown) StatusPill(label: label, color: color),
        ],
      ),
    );
  }

  Widget _countPill(String label, int n, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text('$n',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ]),
        ),
      );

  Widget _detailsTab(BuildContext context, WidgetRef ref, RecordDetail d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: RecordDataView(data: d.data),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Hidden by default'),
            subtitle: const Text('Anyone viewing your record needs an extra tap to see this'),
            value: d.summary.sensitive,
            onChanged: (v) async {
              await ref.read(recordsRepositoryProvider).setSensitive(recordId, v);
              ref.invalidate(_recordProvider(recordId));
              ref.invalidate(recordsListProvider);
            },
          ),
        ),
        if (!d.summary.verified) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/patient/records/$recordId/review'),
            child: const Text('Review & confirm'),
          ),
        ],
      ],
    );
  }

  Widget _documentsTab(RecordDetail d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (d.sourceUrl == null)
          const EmptyState(icon: Icons.description_outlined, title: 'No source document')
        else
          Card(child: Padding(padding: const EdgeInsets.all(12), child: SourceImage(url: d.sourceUrl!))),
      ],
    );
  }
}
