import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final code = profile['medicard_code'] as String? ?? '--------';
    final name = profile['name'] as String? ?? 'Patient';

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediCard'),
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
          Text('Hello, $name', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your MediCard code'),
                  const SizedBox(height: 8),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A doctor enters this to request access. You approve each visit, '
                    'and every view is logged.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/patient/records'),
            icon: const Icon(Icons.folder_shared),
            label: const Text('My records & timeline'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/patient/records/upload'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Add a prescription or report'),
          ),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.lock_clock_outlined),
            title: Text('Access requests & history (Phase 3)'),
            dense: true,
          ),
        ],
      ),
    );
  }
}
