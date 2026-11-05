/// Ambience tracks: id, label, file in assets/ambience/ ('off' has no file).
const List<(String, String, String?)> ambienceTracks = [
  ('off', 'Off', null),
  ('morning_birds', 'Morning birds', 'morning_birds.mp3'),
  ('before_sunrise', 'Before sunrise', 'before_sunrise.mp3'),
  ('heartbeat', 'Heartbeat', 'heartbeat.mp3'),
  ('night', 'Night', 'night.mp3'),
  ('bird', 'Bird', 'bird.mp3'),
];

/// Id of the ambience track used until the player picks another one.
const String defaultAmbienceId = 'morning_birds';

/// Narrator voice and looping background sound. Game and UI code depend on this interface
/// only; the vendor audio package is imported in `audioplayers_audio_service.dart` alone.
abstract class AudioService {
  /// Pushes the saved sound settings (applied immediately).
  void apply({
    required bool sound,
    required double volume,
    required String ambience,
    required bool voice,
  });

  /// Plays `assets/voice/<name>.mp3` unless a clip is speaking: a playing clip is never cut
  /// off (see `VoiceArbiter`). With [variants] > 1 a `_02`, `_03` ... file is picked at random.
  Future<void> voice(String name, {int variants = 1});

  /// Game screen opened / resumed: the ambience loops under the voice.
  Future<void> startAmbience();

  /// Pause and app in background.
  Future<void> pauseAmbience();

  Future<void> dispose();
}

/// Does nothing (default when sound is not wanted).
class NoopAudioService implements AudioService {
  const NoopAudioService();

  @override
  void apply({
    required bool sound,
    required double volume,
    required String ambience,
    required bool voice,
  }) {}

  @override
  Future<void> voice(String name, {int variants = 1}) async {}

  @override
  Future<void> startAmbience() async {}

  @override
  Future<void> pauseAmbience() async {}

  @override
  Future<void> dispose() async {}
}

/// Records what would be played (tests).
class FakeAudioService implements AudioService {
  bool sound = true;
  double volume = 1.0;
  String ambience = defaultAmbienceId;
  bool voiceOn = true;
  bool ambiencePlaying = false;
  final List<String> voices = [];

  @override
  void apply({
    required bool sound,
    required double volume,
    required String ambience,
    required bool voice,
  }) {
    this.sound = sound;
    this.volume = volume;
    this.ambience = ambience;
    voiceOn = voice;
    if (!sound || ambience == 'off') ambiencePlaying = false;
  }

  @override
  Future<void> voice(String name, {int variants = 1}) async {
    if (sound && voiceOn) voices.add(name);
  }

  @override
  Future<void> startAmbience() async {
    ambiencePlaying = sound && ambience != 'off';
  }

  @override
  Future<void> pauseAmbience() async => ambiencePlaying = false;

  @override
  Future<void> dispose() async => ambiencePlaying = false;
}
