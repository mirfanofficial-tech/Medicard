import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/env.dart';
import '../../theme.dart';
import '../../ui/auth_shell.dart';
import '../../ui/widgets.dart';

class PatientAuthScreen extends ConsumerStatefulWidget {
  const PatientAuthScreen({super.key});

  @override
  ConsumerState<PatientAuthScreen> createState() => _PatientAuthScreenState();
}

class _PatientAuthScreenState extends ConsumerState<PatientAuthScreen> {
  final _phone =
      TextEditingController(text: Env.demoPrefill ? '+923001112222' : '');
  final _code = TextEditingController();
  final _name = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _devCode;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Network error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        final dev = await _repo.requestPatientOtp(_phone.text.trim());
        setState(() {
          _codeSent = true;
          _devCode = dev;
          if (Env.demoPrefill && dev != null) _code.text = dev;
        });
      });

  Future<void> _verify() => _run(() async {
        await _repo.verifyPatientOtp(
          phone: _phone.text.trim(),
          code: _code.text.trim(),
          name: _name.text.trim(),
        );
        await ref.read(authControllerProvider.notifier).refresh();
        if (mounted) context.go('/patient');
      });

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      roleLabel: 'For patients',
      headline: 'Your health history,\nalways with you.',
      tagline: 'Keep every prescription and report in one place, and share it with a '
          'doctor only when you say so.',
      points: const [
        AuthPoint(Icons.document_scanner_outlined,
            'Snap a paper prescription or lab report — AI turns it into a clean record.'),
        AuthPoint(Icons.verified_user_outlined,
            'Nothing is saved until you confirm it. Verified data is clearly marked.'),
        AuthPoint(Icons.lock_person_outlined,
            'Doctors see your records only after you approve each visit.'),
      ],
      onBack: _codeSent ? () => setState(() => _codeSent = false) : null,
      child: AuthCard(child: _codeSent ? _otpStep() : _phoneStep()),
    );
  }

  Widget _title(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: MediCardColors.ink)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: MediCardColors.muted, height: 1.4)),
        ],
      );

  Widget _phoneStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _title('Welcome 👋',
              'Sign in or create your account with your phone number. We’ll text you a '
              'one-time code — no password to remember.'),
          const SizedBox(height: 24),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _sendCode(),
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+92 300 1234567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 14), AuthError(_error!)],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: _busy ? const _Spinner() : const Text('Send code'),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: MediCardColors.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text('Your health data is private and encrypted in transit.',
                    style: TextStyle(fontSize: 12, color: MediCardColors.muted)),
              ),
            ],
          ),
          const Divider(height: 36),
          Center(
            child: TextButton(
              onPressed: () => context.go('/doctor/auth'),
              child: const Text('Are you a doctor? Sign in here'),
            ),
          ),
        ],
      );

  Widget _otpStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MediCardColors.primaryTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.sms_outlined, color: MediCardColors.primary, size: 28),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text('Enter the 6-digit code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Sent to ${_phone.text.trim()}',
                style: const TextStyle(color: MediCardColors.muted)),
          ),
          const SizedBox(height: 20),
          PinBoxes(controller: _code, onCompleted: (_) => _verify()),
          if (_devCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text('Dev code: $_devCode',
                    style: const TextStyle(color: MediCardColors.muted, fontSize: 12)),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _verify(),
            decoration: const InputDecoration(
              labelText: 'Your name (first time only)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 14), AuthError(_error!)],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy ? const _Spinner() : const Text('Verify & continue'),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _busy ? null : () => setState(() => _codeSent = false),
                child: const Text('Change number'),
              ),
              const Text('·', style: TextStyle(color: MediCardColors.muted)),
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('Resend code'),
              ),
            ],
          ),
        ],
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
}
