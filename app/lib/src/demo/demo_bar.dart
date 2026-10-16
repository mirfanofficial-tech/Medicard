import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_repository.dart';
import '../theme.dart';
import 'demo_data.dart';
import 'demo_state.dart';

/// Shown only when `DEMO=true`: a slim tab on the right edge. Tap it to jump between the
/// doctor and the patient or to reset the story — handy on one laptop on stage.
class DemoBar extends ConsumerStatefulWidget {
  const DemoBar({super.key});

  @override
  ConsumerState<DemoBar> createState() => _DemoBarState();
}

class _DemoBarState extends ConsumerState<DemoBar> {
  bool _open = false;
  bool _busy = false;

  Future<void> _as(String who) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
      if (who == 'doctor') {
        await repo.loginDoctor(email: demoDoctorEmail, password: 'demo');
      } else {
        await repo.verifyPatientOtp(phone: demoPhone, code: '123456');
      }
      await ref.read(authControllerProvider.notifier).refresh();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _open = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await DemoState.reset();
      await ref.read(authControllerProvider.notifier).logout();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _open = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider).status;
    Widget item(String label, IconData icon, bool on, VoidCallback onTap) =>
        InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(icon,
                  size: 16,
                  color: on ? MediCardColors.primaryDark : Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? MediCardColors.primaryDark : Colors.white)),
            ]),
          ),
        );

    return Material(
      color: Colors.transparent,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_open)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xF20F172A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              item('Doctor', Icons.medical_services_outlined,
                  status == AuthStatus.doctor, () => _as('doctor')),
              item('Patient', Icons.person_outline,
                  status == AuthStatus.patient, () => _as('patient')),
              item('Reset', Icons.restart_alt, false, _reset),
            ]),
          ),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(12)),
          child: Container(
            width: 26,
            height: 74,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xEE0F172A),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: const RotatedBox(
              quarterTurns: 3,
              child: Text('DEMO',
                  style: TextStyle(
                      color: Color(0xFF7CF0D6),
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );
  }
}
