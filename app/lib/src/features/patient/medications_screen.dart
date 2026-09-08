import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import 'patient_repository.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(patientMedicationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Medications')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(patientMedicationsProvider.future),
        child: meds.when(
          loading: () => const LoadingBlock(),
          error: (e, _) => ListView(children: [ErrorBlock(e)]),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const InfoBanner(
                'This list is built from your confirmed prescription records. To add a '
                'medicine, upload the prescription that has it.',
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const EmptyState(
                  icon: Icons.medication_outlined,
                  title: 'No medications on record',
                  subtitle: 'Upload a prescription to see it here.',
                )
              else
                for (final m in rows)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1A16A34A),
                        child: Icon(Icons.medication, color: MediCardColors.success, size: 20),
                      ),
                      title: Text(
                        [m.name, m.dose].where((e) => e != null && e.isNotEmpty).join(' '),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text([
                        if (m.freq != null && m.freq!.isNotEmpty) m.freq,
                        if (m.route != null && m.route!.isNotEmpty) m.route,
                        if (m.sourceDate != null) 'since ${m.sourceDate}',
                      ].where((e) => e != null).join(' · ')),
                    ),
                  ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patient/scan'),
        icon: const Icon(Icons.add),
        label: const Text('Upload prescription'),
      ),
    );
  }
}
