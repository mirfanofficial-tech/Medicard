import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../access/access_repository.dart';
import '../records/models.dart';

final doctorRecordsProvider = FutureProvider.autoDispose
    .family<List<RecordSummary>, String>((ref, pid) {
  return ref.watch(accessRepositoryProvider).patientRecords(pid);
});

class DoctorPatientRecordsScreen extends ConsumerWidget {
  const DoctorPatientRecordsScreen({super.key, required this.patientId});

  final String patientId;

  IconData _icon(String type) => switch (type) {
        'prescription' => Icons.medication,
        'lab' => Icons.science,
        'imaging' => Icons.image,
        _ => Icons.note,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(doctorRecordsProvider(patientId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient record'),
        leading: BackButton(onPressed: () => context.go('/doctor/request')),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: MediCardColors.seed.withOpacity(0.08),
            padding: const EdgeInsets.all(10),
            child: const Text(
              'Consent-based access. This view is logged for the patient.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/doctor/patients/$patientId/ai'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI summary'),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/doctor/patients/$patientId/prescribe'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Prescribe'),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/doctor/patients/$patientId/critical'),
                  icon: const Icon(Icons.emergency_outlined),
                  label: const Text('Critical'),
                ),
              ],
            ),
          ),
          Expanded(
            child: records.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load: $e')),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('No shared records.'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        return ListTile(
                          leading: Icon(_icon(r.type)),
                          title: Text(
                            '${r.type[0].toUpperCase()}${r.type.substring(1)}'
                            '${r.provider != null ? ' · ${r.provider}' : ''}',
                          ),
                          subtitle: Text(r.docDate ?? 'Undated'),
                          trailing: ProvenanceTag(verified: r.verified),
                          onTap: () => context.go(
                            '/doctor/patients/$patientId/records/${r.id}',
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
