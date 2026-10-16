import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper over the platform speech recogniser (browser SpeechRecognition on web,
/// the system recogniser on Android/iOS). Speech never leaves the device/browser vendor
/// and nothing is stored: we only receive the recognised text.
class VoiceInput extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool _ready = false;
  bool _tried = false;
  bool listening = false;
  String? error;

  bool get available => _ready;

  Future<bool> _init() async {
    if (_tried) return _ready;
    _tried = true;
    try {
      _ready = await _stt.initialize(
        onStatus: (s) {
          final on = s == 'listening';
          if (on != listening) {
            listening = on;
            notifyListeners();
          }
        },
        onError: (e) {
          error = e.errorMsg;
          listening = false;
          notifyListeners();
        },
      );
    } catch (_) {
      _ready = false;
    }
    if (!_ready) error ??= 'Voice input is not available on this device/browser.';
    notifyListeners();
    return _ready;
  }

  /// [urdu] picks the recognition language (Urdu-Pakistan or English-Pakistan).
  Future<void> start({
    required void Function(String text, bool isFinal) onText,
    bool urdu = false,
  }) async {
    error = null;
    if (!await _init()) return;
    listening = true;
    notifyListeners();
    await _stt.listen(
      localeId: urdu ? 'ur_PK' : 'en_PK',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stop() async {
    await _stt.stop();
    listening = false;
    notifyListeners();
  }
}
