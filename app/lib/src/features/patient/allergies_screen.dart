import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import 'patient_repository.dart';

class AllergiesScreen extends ConsumerWidget {
  const AllergiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allergies = ref.watch(patientAllergiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Allergies')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(patientAllergiesProvider.future),
        child: allergies.when(
          loading: () => const LoadingBlock(),
          error: (e, _) => ListView(children: [ErrorBlock(e)]),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (rows.isEmpty)
                const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No allergies on record',
                  subtitle: 'These are pulled from your confirmed records.',
                )
              else ...[
                for (final a in rows)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1ADC2626),
                        child: Icon(Icons.warning_amber_rounded,
                            color: MediCardColors.danger, size: 20),
                      ),
                      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('From ${a.sourceRecordIds.length} record(s)'),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              const InfoBanner(
                'Always tell your doctor about your allergies in person. This list is built '
                'from your confirmed records — add one by uploading the record that notes it.',
                icon: Icons.info_outline,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patient/scan'),
        icon: const Icon(Icons.add),
        label: const Text('Upload record'),
      ),
    );
  }
}
