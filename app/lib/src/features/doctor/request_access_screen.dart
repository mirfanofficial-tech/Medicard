import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../access/access_repository.dart';

class RequestAccessScreen extends ConsumerStatefulWidget {
  const RequestAccessScreen({super.key});

  @override
  ConsumerState<RequestAccessScreen> createState() => _State();
}

class _State extends ConsumerState<RequestAccessScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _msg;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _codeText => _code.text.trim().toUpperCase();

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
      _msg = null;
    });
    try {
      await ref.read(accessRepositoryProvider).requestAccess(_codeText);
      ref.invalidate(doctorGrantsProvider);
      setState(() => _msg = 'Request sent. Ask the patient to approve on their phone, '
          'then pull to refresh.');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Request failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _breakGlass() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || reason.trim().length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accessRepositoryProvider).breakGlass(_codeText, reason.trim());
      ref.invalidate(doctorGrantsProvider);
      setState(() => _msg = 'Emergency access opened. It is limited to critical '
          'information and the patient has been notified.');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Emergency access failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grants = ref.watch(doctorGrantsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access a patient record'),
        leading: BackButton(onPressed: () => context.go('/doctor')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(doctorGrantsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'MediCard code',
                hintText: 'e.g. K3M7QP2A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _codeText.length < 6 ? null : _request,
              child: const Text('Request access'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy || _codeText.length < 6 ? null : _breakGlass,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: MediCardColors.danger,
              ),
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency access (critical only)'),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_msg!, style: const TextStyle(color: MediCardColors.verified)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Divider(height: 32),
            Text('Active access', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            grants.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Text('Could not load: $e'),
              data: (rows) => rows.isEmpty
                  ? const Text('No active grants. Request access above.')
                  : Column(children: [for (final g in rows) _grantTile(g)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grantTile(g) {
    final critical = !g.isFull;
    return Card(
      child: ListTile(
        leading: Icon(critical ? Icons.emergency : Icons.folder_shared,
            color: critical ? MediCardColors.danger : null),
        title: Text(g.patientName),
        subtitle: Text(critical
            ? 'Emergency — critical information only'
            : 'Full record · expires ${g.expiresAt.substring(0, 16).replaceFirst("T", " ")}'),
        trailing: Wrap(spacing: 4, children: [
          TextButton(
            onPressed: () => context.go(
              critical
                  ? '/doctor/patients/${g.patientId}/critical'
                  : '/doctor/patients/${g.patientId}/records',
            ),
            child: const Text('Open'),
          ),
          IconButton(
            tooltip: 'End session',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(accessRepositoryProvider).endGrant(g.grantId);
              ref.invalidate(doctorGrantsProvider);
            },
          ),
        ]),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency access'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This bypasses patient consent and is logged and disclosed to the patient. '
            'Use only when the patient cannot consent. State the reason:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Open emergency access'),
        ),
      ],
    );
  }
}
