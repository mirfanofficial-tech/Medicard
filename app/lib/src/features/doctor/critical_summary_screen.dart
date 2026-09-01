import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../access/access_repository.dart';
import '../access/models.dart';

final _criticalProvider =
    FutureProvider.autoDispose.family<CriticalView, String>((ref, pid) {
  return ref.watch(accessRepositoryProvider).patientCritical(pid);
});

class CriticalSummaryScreen extends ConsumerWidget {
  const CriticalSummaryScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crit = ref.watch(_criticalProvider(patientId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Critical summary'),
        leading: BackButton(onPressed: () => context.go('/doctor/request')),
      ),
      body: crit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MediCardColors.danger.withOpacity(0.10),
                border: Border.all(color: MediCardColors.danger.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'CRITICAL-ONLY VIEW · ${c.patientName}\n${c.note}',
                style: const TextStyle(color: MediCardColors.danger, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            _section('Allergies', c.allergies.isEmpty ? ['None recorded'] : c.allergies),
            _medsSection(c.currentMedications),
            _section('Conditions', c.conditions.isEmpty ? ['None recorded'] : c.conditions),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            for (final i in items) Text('• $i'),
          ],
        ),
      );

  Widget _medsSection(List<Map<String, dynamic>> meds) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current medications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            if (meds.isEmpty)
              const Text('• None recorded')
            else
              for (final m in meds)
                Text('• ${m['name']}'
                    '${m['dose'] != null ? ', ${m['dose']}' : ''}'
                    '${m['freq'] != null ? ', ${m['freq']}' : ''}'),
          ],
        ),
      );
}
