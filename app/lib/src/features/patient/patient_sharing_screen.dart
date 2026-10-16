import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';
import '../access/access_repository.dart';
import '../access/models.dart';
import 'patient_repository.dart';

class PatientSharingScreen extends ConsumerWidget {
  const PatientSharingScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(patientGrantsProvider);
    await ref.read(pendingRequestsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(patientMeProvider);
    final pending = ref.watch(pendingRequestsProvider);
    final grants = ref.watch(patientGrantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sharing'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _CodeCard(code: me.asData?.value.medicardCode ?? '········'),
            const SizedBox(height: 24),

            const SectionHeader('Access requests'),
            pending.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load: $e'),
              data: (rows) => rows.isEmpty
                  ? const _MutedCard('No pending requests.')
                  : Column(children: [for (final r in rows) _RequestCard(r)]),
            ),
            const SizedBox(height: 24),

            const SectionHeader('Currently shared with'),
            grants.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load: $e'),
              data: (rows) {
                final active = rows.where((g) => g['ended_at'] == null).toList();
                final past = rows.where((g) => g['ended_at'] != null).toList();
                return Column(
                  children: [
                    if (active.isEmpty)
                      const _MutedCard('Nobody has access right now.')
                    else
                      for (final g in active) _GrantCard(g, active: true),
                    if (past.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const SectionHeader('Past access'),
                      for (final g in past) _GrantCard(g, active: false),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your MediCard code', style: TextStyle(color: MediCardColors.muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: MediCardColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Code copied')));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'A doctor enters this to request access. The code is permanent — you stay in '
              'control by approving each request, and every view is logged.',
              style: TextStyle(fontSize: 12, color: MediCardColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: const TextStyle(color: MediCardColors.muted)),
        ),
      );
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard(this.req);
  final PendingRequest req;
  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(patientGrantsProvider);
      ref.invalidate(accessHistoryProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    final repo = ref.read(accessRepositoryProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                backgroundColor: MediCardColors.primaryTint,
                child: Icon(Icons.medical_services_outlined, color: MediCardColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr ${r.doctorName}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text([r.specialty, r.hospital].where((e) => e != null).join(' · '),
                        style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text('Wants to view: ${r.forPatient}\'s MediCard',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _act(() => repo.deny(r.requestId)),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: MediCardColors.success),
                  onPressed: _busy ? null : () => _act(() => repo.approve(r.requestId)),
                  child: const Text('Approve'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _GrantCard extends ConsumerWidget {
  const _GrantCard(this.g, {required this.active});
  final Map<String, dynamic> g;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = g['scope'] == 'critical' ? 'Emergency (critical only)' : 'Full record';
    final until = prettyUntil(g['expires_at'] as String);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('Dr ${g['doctor_name']}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(active ? '$scope · until $until' : '$scope · ended'),
        trailing: active
            ? TextButton(
                onPressed: () async {
                  await ref
                      .read(accessRepositoryProvider)
                      .revokeGrant(g['grant_id'] as String);
                  ref.invalidate(patientGrantsProvider);
                  ref.invalidate(accessHistoryProvider);
                },
                child: const Text('Revoke'),
              )
            : const StatusPill(label: 'Expired', color: MediCardColors.muted),
      ),
    );
  }
}
