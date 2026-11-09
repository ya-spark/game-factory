import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_service.dart';

/// Text-to-speech through the device voice (the only file that imports `flutter_tts`).
/// Prefers [locale] (en-AU) and falls back to the device default voice.
class TtsSpeechService implements SpeechService {
  TtsSpeechService({this.locale = 'en-AU'});

  final String locale;
  final FlutterTts _tts = FlutterTts();
  bool? _ready;

  Future<bool> _init() async {
    if (_ready != null) return _ready!;
    try {
      final langs = await _tts.getLanguages;
      final has = langs is List && langs.contains(locale);
      if (has) await _tts.setLanguage(locale);
      await _tts.awaitSpeakCompletion(true);
      _ready = langs is List && langs.isNotEmpty;
    } on Object catch (e) {
      debugPrint('TTS unavailable: $e');
      _ready = false;
    }
    return _ready!;
  }

  @override
  Future<bool> get isAvailable => _init();

  @override
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty || !await _init()) return false;
    try {
      await _tts.speak(text);
      return true;
    } on Object catch (e) {
      debugPrint('TTS failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // nothing to stop
    }
  }
}
