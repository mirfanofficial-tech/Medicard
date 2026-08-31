import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';

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
        title: const Text('Patient sign in'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('We send a one-time code to your phone. No password to remember.'),
            const SizedBox(height: 20),
            TextField(
              controller: _phone,
              enabled: !_codeSent,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+92300...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Your name (first time only)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_devCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Dev code: $_devCode',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy
                  ? null
                  : _codeSent
                      ? _verify
                      : _sendCode,
              child: Text(_busy
                  ? 'Please wait...'
                  : _codeSent
                      ? 'Verify & continue'
                      : 'Send code'),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : () => setState(() => _codeSent = false),
                child: const Text('Change number'),
              ),
          ],
        ),
      ),
    );
  }
}
