import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import 'patient_repository.dart';
import 'record_type_ui.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(patientOverviewProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediCard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/patient/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(patientOverviewProvider.future),
        child: overview.when(
          loading: () => const LoadingBlock(),
          error: (e, _) => ListView(children: [ErrorBlock(e)]),
          data: (o) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Hello, ${o.name.split(' ').first} 👋',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              const Text("Here's your health overview",
                  style: TextStyle(color: MediCardColors.muted)),
              const SizedBox(height: 18),
              const SectionHeader('Health Summary'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  StatCard(
                    icon: Icons.folder_copy_outlined,
                    value: '${o.records}',
                    label: 'Records',
                    onTap: () => context.go('/patient/records'),
                  ),
                  StatCard(
                    icon: Icons.warning_amber_rounded,
                    value: '${o.allergies}',
                    label: 'Allergies',
                    color: MediCardColors.danger,
                    onTap: () => context.push('/patient/health/allergies'),
                  ),
                  StatCard(
                    icon: Icons.medication_outlined,
                    value: '${o.medications}',
                    label: 'Medications',
                    color: MediCardColors.success,
                    onTap: () => context.push('/patient/health/medications'),
                  ),
                  StatCard(
                    icon: Icons.science_outlined,
                    value: '${o.labReports}',
                    label: 'Lab Reports',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.go('/patient/records'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionHeader('Recent Activity',
                  onAction: () => context.go('/patient/records')),
              if (o.recent.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No records yet. Add your first below.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < o.recent.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _RecentTile(o.recent[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/patient/scan'),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Upload New Record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile(this.r);
  final RecentRecord r;

  @override
  Widget build(BuildContext context) {
    final ui = recordTypeUi(r.type);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: ui.color.withOpacity(0.12),
        child: Icon(ui.icon, color: ui.color, size: 20),
      ),
      title: Text(ui.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([r.docDate, r.provider].where((e) => e != null).join(' · ')),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/patient/records/${r.recordId}'),
    );
  }
}
