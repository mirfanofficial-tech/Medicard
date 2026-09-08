import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local, device-only preferences. Toggling these never leaves the phone.
class AppSettings {
  const AppSettings({this.push = true, this.medReminders = true, this.biometric = false});

  final bool push;
  final bool medReminders;
  final bool biometric;

  AppSettings copyWith({bool? push, bool? medReminders, bool? biometric}) => AppSettings(
        push: push ?? this.push,
        medReminders: medReminders ?? this.medReminders,
        biometric: biometric ?? this.biometric,
      );
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._store) : super(const AppSettings()) {
    _load();
  }

  final FlutterSecureStorage _store;

  Future<void> _load() async {
    Future<bool> read(String k, bool d) async =>
        (await _store.read(key: k)) == null ? d : (await _store.read(key: k)) == '1';
    state = AppSettings(
      push: await read('set_push', true),
      medReminders: await read('set_meds', true),
      biometric: await read('set_bio', false),
    );
  }

  Future<void> _write(String k, bool v) => _store.write(key: k, value: v ? '1' : '0');

  void setPush(bool v) {
    state = state.copyWith(push: v);
    _write('set_push', v);
  }

  void setMedReminders(bool v) {
    state = state.copyWith(medReminders: v);
    _write('set_meds', v);
  }

  void setBiometric(bool v) {
    state = state.copyWith(biometric: v);
    _write('set_bio', v);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(const FlutterSecureStorage());
});
