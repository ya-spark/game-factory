/// Reads text aloud. Game and UI code depend on this interface only; the vendor
/// text-to-speech package is imported in `tts_speech_service.dart` alone.
abstract interface class SpeechService {
  /// True when a voice can speak on this device.
  Future<bool> get isAvailable;

  /// Speaks [text] (replacing anything still being spoken). Returns true if it spoke.
  Future<bool> speak(String text);

  Future<void> stop();
}

/// Speaks nothing (tests, devices without a voice).
class NoopSpeechService implements SpeechService {
  const NoopSpeechService();
  @override
  Future<bool> get isAvailable async => false;
  @override
  Future<bool> speak(String text) async => false;
  @override
  Future<void> stop() async {}
}

/// Records what was asked to be spoken.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true});
  bool available;
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<bool> get isAvailable async => available;
  @override
  Future<bool> speak(String text) async {
    if (!available) return false;
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

/// Plays a recorded clip of an item (its `audio` file). Returns true if it played, false if the
/// clip is missing or could not play (the caller then falls back to text-to-speech).
typedef RecordedClipPlayer = Future<bool> Function(String audioRef);

/// Reads an item aloud: the recorded `audio` file first when the item has one, text-to-speech
/// as the fallback. Pure Dart.
class ReadAloud {
  ReadAloud({required this.speech, this.recorded});

  final SpeechService speech;
  final RecordedClipPlayer? recorded;

  /// Reads [text]. With an [audioRef] and a player, the recorded clip is tried first.
  /// Returns true if something was read.
  Future<bool> read(String text, {String? audioRef}) async {
    await speech.stop();
    if (audioRef != null && recorded != null) {
      try {
        if (await recorded!(audioRef)) return true;
      } on Object {
        // fall through to text-to-speech
      }
    }
    return speech.speak(text);
  }

  Future<void> stop() => speech.stop();
}

/// The text read for a question: the prompt, then the options numbered.
String questionReadout(String prompt, List<String> options) {
  final b = StringBuffer(prompt);
  for (var i = 0; i < options.length; i++) {
    b.write(' Option ${i + 1}. ${options[i]}.');
  }
  return b.toString();
}
