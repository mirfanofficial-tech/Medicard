import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme.dart';

class DoctorHomeScreen extends ConsumerWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final name = profile['name'] as String? ?? 'Doctor';
    final status = profile['status'] as String? ?? 'pending_verification';
    final verified = status == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediCard — Doctor'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Dr $name', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (verified ? MediCardColors.verified : MediCardColors.unverified)
                  .withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (verified ? MediCardColors.verified : MediCardColors.unverified)
                    .withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(verified ? Icons.verified_user : Icons.hourglass_top,
                    color:
                        verified ? MediCardColors.verified : MediCardColors.unverified),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(verified
                      ? 'Your licence is verified. You can request patient access.'
                      : 'Your account is awaiting licence review. Searching patient '
                          'records is disabled until a reviewer approves it.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: verified ? () => context.go('/doctor/request') : null,
            icon: const Icon(Icons.person_search),
            label: const Text('Access a patient record'),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('Advisory AI summary'),
            subtitle: Text('Open a patient record, then tap “AI summary”. It never prescribes.'),
            dense: true,
          ),
        ],
      ),
    );
  }
}
