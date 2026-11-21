import 'package:game_core/kit/audio/audio.dart' hide ambienceTracks;

/// The background sounds Blockfall offers (files in game_core's assets/audio/ambience/; 'off' has none).
const List<(String, String, String?)> ambienceTracks = [
  ('off', 'Off', null),
  ('morning_birds', 'Morning birds', 'morning_birds.mp3'),
  ('heartbeat', 'Heartbeat', 'heartbeat.mp3'),
];

/// Blockfall's sound: the shared audio kit with this game's tracks.
AudioService newBlockfallAudio() => AudioplayersAudioService(
  tracks: ambienceTracks,
  defaultAmbience: 'morning_birds',
);
