/// Ambience tracks: id, label, file in assets/ambience/ ('off' has no file).
const List<(String, String, String?)> ambienceTracks = [
  ('off', 'Off', null),
  ('morning_birds', 'Morning birds', 'morning_birds.mp3'),
  ('before_sunrise', 'Before sunrise', 'before_sunrise.mp3'),
  ('heartbeat', 'Heartbeat', 'heartbeat.mp3'),
  ('night', 'Night', 'night.mp3'),
  ('bird', 'Bird', 'bird.mp3'),
  // Sound packs bought in the Shop (`shop.sound_packs`); a pack id is also its shop item id.
  ('rain', 'Rain', 'rain.mp3'),
  ('waves', 'Waves', 'waves.mp3'),
  ('forest_wind', 'Forest wind', 'forest_wind.mp3'),
  ('fireplace', 'Fireplace', 'fireplace.mp3'),
];

/// Ambience tracks that must be bought first.
const Set<String> soundPackIds = {'rain', 'waves', 'forest_wind', 'fireplace'};

/// The ambience to play for a saved choice: a pack that is not owned (or whose shop is off)
/// falls back to the default track. Everything else is used as saved.
String resolveAmbience(
  String saved, {
  required Set<String> owned,
  required bool packsEnabled,
}) {
  if (!soundPackIds.contains(saved)) return saved;
  return packsEnabled && owned.contains(saved) ? saved : defaultAmbienceId;
}

/// How long a sound pack sample plays in the Shop.
const Duration ambiencePreviewLength = Duration(seconds: 10);

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

  /// Plays a short sample ([ambiencePreviewLength]) of an ambience track, for the Shop.
  /// Respects the Sound switch and master volume; stops by itself or with [stopPreview].
  Future<void> previewAmbience(String id);

  Future<void> stopPreview();

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
  Future<void> previewAmbience(String id) async {}

  @override
  Future<void> stopPreview() async {}

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

  /// Ambience ids sampled, in order; [previewing] is the one playing now.
  final List<String> previews = [];
  String? previewing;

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
  Future<void> previewAmbience(String id) async {
    if (!sound) return;
    previews.add(id);
    previewing = id;
  }

  @override
  Future<void> stopPreview() async => previewing = null;

  @override
  Future<void> dispose() async => ambiencePlaying = false;
}
