import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../access/access_repository.dart';
import '../records/models.dart';
import '../records/record_data_view.dart';

final _detailProvider = FutureProvider.autoDispose
    .family<RecordDetail, ({String pid, String rid})>((ref, k) {
  return ref.watch(accessRepositoryProvider).patientRecordDetail(k.pid, k.rid);
});

class DoctorRecordDetailScreen extends ConsumerWidget {
  const DoctorRecordDetailScreen({
    super.key,
    required this.patientId,
    required this.recordId,
  });

  final String patientId;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider((pid: patientId, rid: recordId)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record'),
        leading: BackButton(
          onPressed: () => context.go('/doctor/patients/$patientId/records'),
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Text(d.summary.type.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              ProvenanceTag(verified: d.summary.verified),
            ]),
            const SizedBox(height: 4),
            Text('${d.summary.docDate ?? 'Undated'}'
                '${d.summary.provider != null ? ' · ${d.summary.provider}' : ''}'),
            const Divider(height: 24),
            RecordDataView(data: d.data),
          ],
        ),
      ),
    );
  }
}
