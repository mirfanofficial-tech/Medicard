import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import '../access/access_repository.dart';
import '../access/models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  (IconData, Color) _icon(String action) => switch (action) {
        'break_glass' => (Icons.emergency, MediCardColors.danger),
        'grant' => (Icons.check_circle, MediCardColors.success),
        'prescribe' => (Icons.edit_note, MediCardColors.primary),
        'view' => (Icons.visibility, MediCardColors.muted),
        'request' => (Icons.person_add_alt, MediCardColors.primary),
        _ => (Icons.notifications_none, MediCardColors.muted),
      };

  String _label(String action) => switch (action) {
        'break_glass' => 'Emergency access used',
        'grant' => 'You approved access',
        'deny' => 'You declined a request',
        'revoke' => 'You revoked access',
        'end' => 'A doctor ended their session',
        'view' => 'A doctor viewed your record',
        'request' => 'New access request',
        'prescribe' => 'A doctor added a prescription',
        _ => action,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRequestsProvider);
    final history = ref.watch(accessHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingRequestsProvider);
          ref.invalidate(accessHistoryProvider);
          await ref.read(accessHistoryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            pending.maybeWhen(
              data: (rows) => rows.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        for (final r in rows)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: MediCardColors.primaryTint,
                                child: Icon(Icons.person_add_alt,
                                    color: MediCardColors.primary, size: 20),
                              ),
                              title: Text('Dr ${r.doctorName} wants to view your MediCard',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  [r.specialty, r.hospital].where((e) => e != null).join(' · ')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/patient/sharing'),
                            ),
                          ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            history.when(
              loading: () => const LoadingBlock(),
              error: (e, _) => ErrorBlock(e),
              data: (rows) => rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none, title: 'Nothing yet')
                  : Column(children: [for (final e in rows) _tile(e)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AuditEntry e) {
    final (icon, color) = _icon(e.action);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(_label(e.action), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if (e.doctorName != null) 'Dr ${e.doctorName}',
          if (e.reason != null) 'reason: ${e.reason}',
          e.at.substring(0, 16).replaceFirst('T', ' '),
        ].join(' · ')),
      ),
    );
  }
}
