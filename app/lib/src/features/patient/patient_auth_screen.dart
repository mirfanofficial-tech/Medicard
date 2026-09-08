import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';

class PatientAuthScreen extends ConsumerStatefulWidget {
  const PatientAuthScreen({super.key});

  @override
  ConsumerState<PatientAuthScreen> createState() => _PatientAuthScreenState();
}

class _PatientAuthScreenState extends ConsumerState<PatientAuthScreen> {
  final _phone = TextEditingController();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_codeSent ? 'Verify code' : 'Sign in'),
        leading: BackButton(
          onPressed: () => _codeSent ? setState(() => _codeSent = false) : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: _codeSent ? _otpStep() : _phoneStep(),
        ),
      ),
    );
  }

  List<Widget> _phoneStep() => [
        const Text('Welcome 👋',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MediCardColors.ink)),
        const SizedBox(height: 4),
        const Text('We send a one-time code to your phone. No password to remember.',
            style: TextStyle(color: MediCardColors.muted)),
        const SizedBox(height: 24),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+92 300 1234567',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _sendCode,
          child: Text(_busy ? 'Please wait…' : 'Send code'),
        ),
      ];

  List<Widget> _otpStep() => [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MediCardColors.primaryTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.sms_outlined, color: MediCardColors.primary, size: 30),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('Enter the 6-digit code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('Sent to ${_phone.text.trim()}',
              style: const TextStyle(color: MediCardColors.muted)),
        ),
        const SizedBox(height: 20),
        PinBoxes(controller: _code, onCompleted: (_) => _verify()),
        if (_devCode != null)
          Center(
            child: Text('Dev code: $_devCode',
                style: const TextStyle(color: MediCardColors.muted, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Your name (first time only)',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Verifying…' : 'Verify & continue'),
        ),
        TextButton(
          onPressed: _busy ? null : _sendCode,
          child: const Text('Resend code'),
        ),
      ];
}
