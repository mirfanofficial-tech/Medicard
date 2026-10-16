import 'package:flutter/foundation.dart';

/// App configuration, set at build/run time (there is no .env file on a compiled app):
///
///   flutter run -d chrome --dart-define-from-file=env/demo.json    # static MVP demo, no server
///   flutter run -d chrome --dart-define-from-file=env/local.json   # local backend
///   flutter build apk     --dart-define-from-file=env/live.json    # hosted backend
///
/// or individually: --dart-define=DEMO=true / --dart-define=API_BASE_URL=http://...
class Env {
  /// DEMO=true: the whole app runs on static data (Ayesha + Dr Sara) — no network,
  /// no API calls, nothing to deploy. For the hackathon MVP demo.
  static const demo = bool.fromEnvironment('DEMO');

  static const _override = String.fromEnvironment('API_BASE_URL');

  /// With no override: debug runs talk to the local backend on http://localhost:8010;
  /// release builds talk to the hosted backend.
  static String get apiBaseUrl => _override.isNotEmpty
      ? _override
      : (kDebugMode ? 'http://localhost:8010' : 'https://qamartech.org/api');

  /// Pre-fills the sign-in forms with the seeded demo accounts. Always on in demo mode.
  static const _prefill = bool.fromEnvironment('DEMO_PREFILL');
  static bool get demoPrefill => demo || _prefill;
}
