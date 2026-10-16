import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../theme.dart';
import '../access/access_repository.dart';
import '../access/models.dart';
import 'patient_repository.dart';

/// Sits over the patient app and pops up the moment a doctor asks to see their records,
/// so the patient can say yes (or no) without hunting for a menu.
class RequestWatcher extends ConsumerStatefulWidget {
  const RequestWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RequestWatcher> createState() => _RequestWatcherState();
}

class _RequestWatcherState extends ConsumerState<RequestWatcher> {
  Timer? _timer;
  final _shown = <String>{};
  bool _open = false;

  @override
  void initState() {
    super.initState();
    const every = Env.demo ? Duration(seconds: 2) : Duration(seconds: 15);
    _timer = Timer.periodic(every, (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted || _open) return;
    List<PendingRequest> pending;
    try {
      pending = await ref.read(accessRepositoryProvider).pendingRequests();
    } catch (_) {
      return;
    }
    final fresh = pending.where((p) => !_shown.contains(p.requestId)).toList();
    if (fresh.isEmpty || !mounted) return;
    final req = fresh.first;
    _shown.add(req.requestId);
    _open = true;
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestDialog(req: req),
    );
    _open = false;
    if (allow == null) return;
    final repo = ref.read(accessRepositoryProvider);
    try {
      allow ? await repo.approve(req.requestId) : await repo.deny(req.requestId);
    } catch (_) {}
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(patientGrantsProvider);
    ref.invalidate(patientHomeProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(allow
            ? 'Done. Dr ${req.doctorName} can now see your records for 12 hours.'
            : 'Request declined. Nothing was shared.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RequestDialog extends StatelessWidget {
  const _RequestDialog({required this.req});
  final PendingRequest req;

  @override
  Widget build(BuildContext context) {
    final initials =
        req.doctorName.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [MediCardColors.primaryDark, MediCardColors.primary],
                ),
                boxShadow: [
                  BoxShadow(
                      color: MediCardColors.primary.withOpacity(0.3),
                      blurRadius: 22,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Text(initials.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 18),
            const Text('A doctor wants to see your records',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Dr ${req.doctorName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MediCardColors.primary)),
            Text([req.specialty, req.hospital].whereType<String>().join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: MediCardColors.muted, fontSize: 13.5)),
            const SizedBox(height: 6),
            const StatusPill(label: 'Licence verified', color: MediCardColors.verified, icon: Icons.verified),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: MediCardColors.primaryTint, borderRadius: BorderRadius.circular(16)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Point(Icons.timer_outlined, 'Access ends automatically after 12 hours'),
                _Point(Icons.visibility_off_outlined, 'Anything you marked private stays hidden'),
                _Point(Icons.history, 'Everything they open is saved in your access history'),
                _Point(Icons.block, 'You can take access back any time'),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MediCardColors.danger,
                    side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text('No, not now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  child: const Text('Yes, allow access', style: TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: MediCardColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.3))),
        ]),
      );
}
