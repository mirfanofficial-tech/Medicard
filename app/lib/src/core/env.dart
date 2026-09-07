/// Base URL of the MediCard API.
///
/// Override at run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///
/// Default target is the Android emulator loopback (10.0.2.2 -> host localhost).
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
