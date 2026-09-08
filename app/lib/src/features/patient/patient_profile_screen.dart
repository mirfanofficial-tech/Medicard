import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import 'patient_repository.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(patientMeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: MediCardColors.primaryTint,
                    child: Icon(Icons.person, color: MediCardColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.asData?.value.name ?? 'Patient',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Patient ID: ${me.asData?.value.medicardCode ?? '—'}',
                          style: const TextStyle(fontSize: 12, color: MediCardColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  onTap: () => context.push('/patient/profile/personal'),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.medication_outlined,
                  title: 'Medications',
                  onTap: () => context.push('/patient/health/medications'),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'Allergies & Conditions',
                  onTap: () => context.push('/patient/health/allergies'),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.history,
                  title: 'Access History',
                  onTap: () => context.push('/patient/sharing/activity'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                MenuTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => context.push('/patient/profile/settings'),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () => context.push('/patient/profile/help'),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.info_outline,
                  title: 'About MediCard',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'MediCard',
                    applicationVersion: '0.1.0',
                    children: const [
                      Text('Your health history, in your hands. AI in MediCard is advisory '
                          'only — it never prescribes.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
