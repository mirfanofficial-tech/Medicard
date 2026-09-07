import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';

class DoctorAuthScreen extends ConsumerStatefulWidget {
  const DoctorAuthScreen({super.key});

  @override
  ConsumerState<DoctorAuthScreen> createState() => _DoctorAuthScreenState();
}

class _DoctorAuthScreenState extends ConsumerState<DoctorAuthScreen> {
  bool _register = true;
  bool _busy = false;
  String? _error;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _licence = TextEditingController();
  final _specialty = TextEditingController();
  final _hospital = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _licence, _specialty, _hospital]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await _repo.registerDoctor(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          licenceNo: _licence.text.trim(),
          specialty: _specialty.text.trim(),
          hospital: _hospital.text.trim(),
        );
      } else {
        await _repo.loginDoctor(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      await ref.read(authControllerProvider.notifier).refresh();
      if (mounted) context.go('/doctor');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Network error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_register ? 'Doctor registration' : 'Doctor sign in'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Register')),
                ButtonSegment(value: false, label: Text('Sign in')),
              ],
              selected: {_register},
              onSelectionChanged: (s) => setState(() => _register = s.first),
            ),
            const SizedBox(height: 20),
            if (_register) ...[
              _field(_name, 'Full name'),
              _field(_licence, 'PMDC licence number'),
              _field(_specialty, 'Specialty (optional)'),
              _field(_hospital, 'Hospital / clinic (optional)'),
            ],
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            _field(_password, 'Password', obscure: true),
            if (_register)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'New accounts are reviewed against the licence register before they '
                  'can search patient records.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy
                  ? 'Please wait...'
                  : _register
                      ? 'Create account'
                      : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
