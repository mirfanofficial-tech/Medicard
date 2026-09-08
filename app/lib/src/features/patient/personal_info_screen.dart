import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import 'patient_repository.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _State();
}

class _State extends ConsumerState<PersonalInfoScreen> {
  bool _editing = false;
  bool _busy = false;
  String? _error;

  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _gender = TextEditingController();
  final _blood = TextEditingController();
  final _address = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _dob, _gender, _blood, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(PatientProfile p) {
    _name.text = p.name;
    _dob.text = p.dob ?? '';
    _gender.text = p.gender ?? '';
    _blood.text = p.bloodGroup ?? '';
    _address.text = p.address ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(patientRepositoryProvider).updateMe({
        'name': _name.text.trim(),
        'dob': _dob.text.trim().isEmpty ? null : _dob.text.trim(),
        'gender': _gender.text.trim(),
        'blood_group': _blood.text.trim(),
        'address': _address.text.trim(),
      });
      ref.invalidate(patientMeProvider);
      if (mounted) setState(() => _editing = false);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Could not save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(patientMeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
        actions: [
          if (!_editing)
            TextButton(onPressed: () => setState(() => _editing = true), child: const Text('Edit')),
        ],
      ),
      body: me.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorBlock(e),
        data: (p) {
          if (!_loaded || !_editing) _fill(p);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field('Full Name', _name),
              _field('Date of Birth', _dob, hint: 'YYYY-MM-DD'),
              _field('Gender', _gender),
              _field('Blood Group', _blood),
              _readonly('Phone Number', p.phone ?? '—'),
              _field('Address', _address, maxLines: 2),
              _readonly('MediCard ID', p.medicardCode),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (_editing) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving...' : 'Save changes'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _editing = false;
                            _loaded = false;
                          }),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          enabled: _editing,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  Widget _readonly(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(value.isEmpty ? '—' : value,
              style: const TextStyle(color: MediCardColors.muted)),
        ),
      );
}
