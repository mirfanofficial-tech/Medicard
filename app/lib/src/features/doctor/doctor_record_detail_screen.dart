import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../theme.dart';
import '../access/access_repository.dart';
import '../records/models.dart';
import '../records/record_data_view.dart';
import 'doctor_top_bar.dart';

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

  ({IconData icon, Color color, String label}) _style(String type) => switch (type) {
        'lab' => (icon: Icons.science, color: const Color(0xFF16A34A), label: 'Lab report'),
        'prescription' => (icon: Icons.medication, color: const Color(0xFFF59E0B), label: 'Prescription'),
        'imaging' => (icon: Icons.photo_camera, color: const Color(0xFF2563EB), label: 'Imaging'),
        _ => (icon: Icons.medical_services, color: const Color(0xFF8B5CF6), label: 'Clinic note'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider((pid: patientId, rid: recordId)));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width >= 700 ? 28 : 14, vertical: 16),
              children: [
                DoctorTopBar(showBack: false, patientId: patientId),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => context.go('/doctor/patients/$patientId/records'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to patient'),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                ),
                detail.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load this record.\n$e'),
                  ),
                  data: (d) {
                    final st = _style(d.summary.type);
                    return Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: MediCardColors.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                color: st.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(15)),
                            child: Icon(st.icon, color: st.color, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(st.label,
                                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                              Text(
                                [
                                  if (d.summary.docDate != null) prettyDate(d.summary.docDate),
                                  if (d.summary.provider != null) d.summary.provider!,
                                ].join(' · '),
                                style: const TextStyle(color: MediCardColors.muted, fontSize: 13.5),
                              ),
                            ]),
                          ),
                          ProvenanceTag(verified: d.summary.verified),
                        ]),
                        const Divider(height: 32),
                        RecordDataView(data: d.data),
                      ]),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
