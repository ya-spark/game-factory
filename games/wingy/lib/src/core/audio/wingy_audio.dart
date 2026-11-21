import 'package:game_core/kit/audio/audio.dart' hide ambienceTracks;

/// The background sounds Wingy offers (files in game_core's assets/audio/ambience/; 'off' has none).
const List<(String, String, String?)> ambienceTracks = [
  ('off', 'Off', null),
  ('night', 'Night', 'night.mp3'),
  ('bird', 'Bird', 'bird.mp3'),
  ('morning_birds', 'Morning birds', 'morning_birds.mp3'),
  ('heartbeat', 'Heartbeat', 'heartbeat.mp3'),
];

/// Wingy's sound: the shared audio kit with this game's tracks and its own effects (`assets/sfx/<name>.wav`, a package asset of this game).
AudioService newWingyAudio() => AudioplayersAudioService(
  tracks: ambienceTracks,
  defaultAmbience: 'night',
  sfxBase: 'packages/game_wingy/assets/',
);
