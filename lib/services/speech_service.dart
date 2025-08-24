import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  Future<bool> init() async {
    _available = await _stt.initialize();
    return _available;
  }

  Future<void> start(Function(String) onText) async {
    if (!_available) {
      _available = await _stt.initialize();
    }
    if (!_available) return;
    await _stt.listen(
      onResult: (r) => onText(r.recognizedWords),
      listenMode: ListenMode.dictation,
    );
  }

  Future<void> stop() async {
    await _stt.stop();
  }

  Future<void> cancel() async {
    await _stt.cancel();
  }
}