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

class DoctorAuthScreen extends ConsumerStatefulWidget {
  const DoctorAuthScreen({super.key});

  @override
  ConsumerState<DoctorAuthScreen> createState() => _DoctorAuthScreenState();
}

class _DoctorAuthScreenState extends ConsumerState<DoctorAuthScreen> {
  bool _register = !Env.demoPrefill;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  final _name = TextEditingController();
  final _email = TextEditingController(
      text: Env.demoPrefill ? 'sara.ahmed@medicard-demo.com' : '');
  final _password =
      TextEditingController(text: Env.demoPrefill ? 'demodemo123' : '');
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

  String? _validate() {
    if (_register && _name.text.trim().length < 2) return 'Enter your full name.';
    if (_register && _licence.text.trim().length < 3) {
      return 'Enter your PMDC licence number.';
    }
    if (!_email.text.contains('@')) return 'Enter a valid email address.';
    if (_password.text.length < (_register ? 8 : 1)) {
      return _register ? 'Password must be at least 8 characters.' : 'Enter your password.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
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
    return AuthShell(
      roleLabel: 'For doctors',
      headline: 'The full picture,\nwith the patient’s consent.',
      tagline: 'See a patient’s verified history in seconds — no paper files, no phone '
          'calls to other clinics.',
      points: const [
        AuthPoint(Icons.badge_outlined,
            'Your PMDC licence is checked before you can search any patient.'),
        AuthPoint(Icons.key_outlined,
            'Access is per visit: the patient approves it, it expires, and it is logged.'),
        AuthPoint(Icons.auto_awesome_outlined,
            'Advisory AI highlights trends and interactions — you make every clinical call.'),
      ],
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthToggle(
              leftLabel: 'Register',
              rightLabel: 'Sign in',
              leftSelected: _register,
              onChanged: (v) => setState(() {
                _register = v;
                _error = null;
              }),
            ),
            const SizedBox(height: 22),
            Text(_register ? 'Doctor registration' : 'Doctor sign in',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: MediCardColors.ink)),
            const SizedBox(height: 6),
            Text(
              _register
                  ? 'Create your account to request access to patient records.'
                  : 'Welcome back. Sign in to continue.',
              style: const TextStyle(color: MediCardColors.muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            if (_register) ...[
              _field(_name, 'Full name', Icons.person_outline,
                  hints: const [AutofillHints.name]),
              _field(_licence, 'PMDC licence number', Icons.badge_outlined),
              _field(_specialty, 'Specialty (optional)', Icons.medical_services_outlined),
              _field(_hospital, 'Hospital / clinic (optional)', Icons.local_hospital_outlined),
            ],
            _field(_email, 'Email', Icons.mail_outline,
                keyboard: TextInputType.emailAddress,
                hints: const [AutofillHints.email]),
            _field(_password, 'Password', Icons.lock_outline,
                obscure: !_showPassword,
                last: true,
                hints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(_showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                )),
            if (_register)
              const InfoBanner(
                'New accounts are reviewed against the licence register before they '
                'can search patient records.',
                icon: Icons.verified_outlined,
              ),
            if (_error != null) ...[const SizedBox(height: 14), AuthError(_error!)],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_register ? 'Create account' : 'Sign in'),
            ),
            const Divider(height: 36),
            Center(
              child: TextButton(
                onPressed: () => context.go('/patient/auth'),
                child: const Text('Not a doctor? Patient sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool obscure = false,
    bool last = false,
    TextInputType? keyboard,
    Iterable<String>? hints,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        autofillHints: hints,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: last ? (_) => _busy ? null : _submit() : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
