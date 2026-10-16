import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../theme.dart';
import '../access/access_repository.dart';
import '../access/models.dart';

class AccessHistoryScreen extends ConsumerWidget {
  const AccessHistoryScreen({super.key});

  (String, IconData, Color?) _look(String action) => switch (action) {
        'break_glass' => ('Emergency access', Icons.emergency, MediCardColors.danger),
        'grant' => ('You approved access', Icons.check_circle, MediCardColors.verified),
        'deny' => ('You denied a request', Icons.block, null),
        'revoke' => ('You revoked access', Icons.logout, null),
        'end' => ('Doctor ended session', Icons.logout, null),
        'view' => ('Record viewed', Icons.visibility, null),
        'request' => ('Access requested', Icons.person_add, null),
        'prescribe' => ('Prescription added', Icons.edit_note, MediCardColors.primary),
        _ => (action, Icons.circle, null),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(accessHistoryProvider);
    final grants = ref.watch(patientGrantsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access history'),
        leading: BackButton(onPressed: () => context.go('/patient')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(patientGrantsProvider);
          ref.invalidate(accessHistoryProvider);
          await ref.read(accessHistoryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Who can see your record now',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            grants.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load: $e'),
              data: (rows) {
                final active = rows.where((g) => g['ended_at'] == null).toList();
                if (active.isEmpty) return const Text('Nobody. No active access.');
                return Column(children: [
                  for (final g in active)
                    Card(
                      child: ListTile(
                        title: Text('Dr ${g['doctor_name']}'),
                        subtitle: Text(
                          '${g['scope'] == 'critical' ? 'Emergency (critical only)' : 'Full record'}'
                          ' · until ${prettyUntil(g['expires_at'] as String)}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(accessRepositoryProvider)
                                .revokeGrant(g['grant_id'] as String);
                            ref.invalidate(patientGrantsProvider);
                            ref.invalidate(accessHistoryProvider);
                          },
                          child: const Text('Revoke'),
                        ),
                      ),
                    ),
                ]);
              },
            ),
            const Divider(height: 32),
            Text('Everything that happened', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load: $e'),
              data: (rows) => rows.isEmpty
                  ? const Text('Nothing yet.')
                  : Column(children: [for (final e in rows) _tile(e)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AuditEntry e) {
    final (label, icon, color) = _look(e.action);
    final who = e.doctorName != null ? 'Dr ${e.doctorName}' : null;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: Text([
        if (who != null) who,
        if (e.hospital != null) e.hospital,
        if (e.scope == 'critical') 'critical info only',
        if (e.reason != null) 'reason: ${e.reason}',
        prettyStamp(e.at),
      ].join(' · ')),
    );
  }
}
