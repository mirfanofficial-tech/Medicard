import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The few things that change during the demo (consent, ticks, a saved prescription,
/// a scanned record). Stored in shared preferences — on web that is localStorage — so a
/// doctor tab and a patient tab on the same browser see each other's actions.
class DemoState {
  DemoState._(this._prefs, this.data);

  static const _key = 'medicard_demo_state_v1';

  final SharedPreferences _prefs;
  Map<String, dynamic> data;

  static Map<String, dynamic> _fresh() => {
        'status': 'none', // none | pending | approved | denied
        'requested_at': null,
        'granted_at': null,
        'rx': null,
        'extra': <Map<String, dynamic>>[],
        'ticks': <String, dynamic>{},
        'log': <Map<String, dynamic>>[],
      };

  /// Always re-reads storage, so changes made in another tab are picked up.
  static Future<DemoState> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_key);
    Map<String, dynamic> d = _fresh();
    if (raw != null) {
      try {
        d = {..._fresh(), ...Map<String, dynamic>.from(jsonDecode(raw) as Map)};
      } catch (_) {}
    }
    return DemoState._(prefs, d);
  }

  Future<void> save() => _prefs.setString(_key, jsonEncode(data));

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  String get status => data['status'] as String? ?? 'none';
  set status(String v) => data['status'] = v;

  bool get granted => status == 'approved' && !expired;
  bool get pending => status == 'pending';

  DateTime? get grantedAt =>
      data['granted_at'] == null ? null : DateTime.tryParse(data['granted_at'] as String);
  DateTime? get requestedAt =>
      data['requested_at'] == null ? null : DateTime.tryParse(data['requested_at'] as String);
  DateTime? get expiresAt => grantedAt?.add(const Duration(hours: 12));
  bool get expired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic>? get emergency =>
      data['emergency'] == null ? null : Map<String, dynamic>.from(data['emergency'] as Map);
  DateTime? get emergencyAt =>
      emergency == null ? null : DateTime.tryParse('${emergency!['at']}');
  DateTime? get emergencyExpires => emergencyAt?.add(const Duration(hours: 1));
  bool get emergencyActive =>
      emergencyExpires != null && DateTime.now().isBefore(emergencyExpires!);

  Map<String, dynamic>? get rx =>
      data['rx'] == null ? null : Map<String, dynamic>.from(data['rx'] as Map);

  List<Map<String, dynamic>> get extra => (data['extra'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  List<Map<String, dynamic>> get log => (data['log'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  void addLog(String action, String text, {String? scope}) {
    final l = log
      ..insert(0, {
        'at': DateTime.now().toIso8601String(),
        'action': action,
        'text': text,
        if (scope != null) 'scope': scope,
      });
    data['log'] = l.take(30).toList();
  }

  Set<String> ticksFor(String ymd) {
    final t = Map<String, dynamic>.from(data['ticks'] as Map? ?? {});
    return ((t[ymd] as List?) ?? []).map((e) => '$e').toSet();
  }

  void setTick(String ymd, String key, bool done) {
    final t = Map<String, dynamic>.from(data['ticks'] as Map? ?? {});
    final s = ((t[ymd] as List?) ?? []).map((e) => '$e').toSet();
    done ? s.add(key) : s.remove(key);
    t[ymd] = s.toList();
    data['ticks'] = t;
  }
}
