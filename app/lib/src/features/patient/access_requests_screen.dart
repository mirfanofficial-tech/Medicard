import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../access/access_repository.dart';

class AccessRequestsScreen extends ConsumerWidget {
  const AccessRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access requests'),
        leading: BackButton(onPressed: () => context.go('/patient')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(pendingRequestsProvider.future),
        child: pending.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('Could not load: $e')),
          ]),
          data: (rows) => rows.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No pending requests.')),
                ])
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [for (final r in rows) _RequestCard(request: r)],
                ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request});
  final dynamic request;

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
      ref.invalidate(accessHistoryProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final repo = ref.read(accessRepositoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dr ${r.doctorName}', style: Theme.of(context).textTheme.titleMedium),
            if (r.hospital != null || r.specialty != null)
              Text([r.specialty, r.hospital].where((e) => e != null).join(' · ')),
            const SizedBox(height: 4),
            Text('wants to view: ${r.forPatient}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _act(() => repo.deny(r.requestId)),
                  child: const Text('Deny'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : () => _act(() => repo.approve(r.requestId)),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
