import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:game_core/kit/audio/voice_arbiter.dart';

/// Blockfall's sounds are package assets: the bundle key carries `packages/game_blockfall/`, so its players
/// use an AudioCache with no `assets/` prefix (the default cache looks in the app's assets).
/// Narrator voice and ambience are shared by the games: they live in game_core.
const String _sharedAudio = 'packages/game_core/assets/audio/';
final AudioCache _cache = AudioCache(prefix: '');
AudioPlayer _newPlayer() => AudioPlayer()..audioCache = _cache;

/// Ambience tracks: id, label, file in assets/ambience/ ('off' has no file).
const List<(String, String, String?)> ambienceTracks = [
  ('off', 'Off', null),
  ('morning_birds', 'Morning birds', 'morning_birds.mp3'),
  ('heartbeat', 'Heartbeat', 'heartbeat.mp3'),
];

/// Plays the narrator voice and the looping background sound. Failures (missing plugin in
/// tests, no audio device) are swallowed: sound is never worth crashing a game.
class AudioService {
  AudioService({Random? random}) : _random = random ?? Random() {
    _arbiter = VoiceArbiter(_VoicePlayerOutput(this), onSpeaking: _duck);
  }

  final Random _random;
  AudioPlayer? _voice;
  AudioPlayer? _ambience;
  late final VoiceArbiter _arbiter;

  /// Settings, kept in sync with the profile via [apply].
  bool enabled = true;
  bool voiceOn = true;
  double masterVolume = 1.0;
  String ambienceId = 'morning_birds';

  bool _ambienceWanted = false;
  bool _ambiencePlaying = false;
  String? _ambienceLoaded;

  static const double ambienceVolume = 0.25;
  static const double ambienceDuckedVolume = 0.1;

  /// Voice and ambience never take Android audio focus, so they cannot interrupt each other.
  static final AudioContext _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  void apply({
    required bool sound,
    required double volume,
    required String ambience,
    required bool voice,
  }) {
    enabled = sound;
    masterVolume = volume;
    voiceOn = voice;
    if (ambience != ambienceId) {
      ambienceId = ambience;
      _ambienceLoaded = null;
    }
    unawaited(_syncAmbience());
  }

  /// Plays `assets/voice/<name>.mp3` unless a clip is speaking (see [VoiceArbiter]).
  /// A name with `_02` variants may pass [variants] to pick one at random.
  Future<void> voice(String name, {int variants = 1}) async {
    if (!enabled || !voiceOn) return;
    final n = variants <= 1 ? 1 : _random.nextInt(variants) + 1;
    final file = n == 1 ? name : '${name}_${n.toString().padLeft(2, '0')}';
    try {
      await _arbiter.say('voice/$file.mp3', voicePriorityOf(name));
    } catch (e) {
      debugPrint('audio: voice/$file failed: $e');
    }
  }

  /// Game screen opened / resumed.
  Future<void> startAmbience() {
    _ambienceWanted = true;
    return _syncAmbience();
  }

  /// Pause and app in background.
  Future<void> pauseAmbience() {
    _ambienceWanted = false;
    return _syncAmbience();
  }

  Future<void> _syncAmbience() async {
    String? file;
    for (final t in ambienceTracks) {
      if (t.$1 == ambienceId) file = t.$3;
    }
    final shouldPlay = _ambienceWanted && enabled && file != null;
    try {
      if (!shouldPlay) {
        if (_ambiencePlaying) await _ambience?.pause();
        _ambiencePlaying = false;
        return;
      }
      final pl = _ambience ??= _newPlayer()..setAudioContext(_context);
      await pl.setReleaseMode(ReleaseMode.loop);
      await pl.setVolume(_ambienceLevel());
      if (_ambienceLoaded != file) {
        _ambienceLoaded = file;
        await pl.play(AssetSource('${_sharedAudio}ambience/$file'));
      } else if (!_ambiencePlaying) {
        await pl.resume();
      }
      _ambiencePlaying = true;
    } catch (e) {
      debugPrint('audio: ambience failed: $e');
    }
  }

  double _ambienceLevel() =>
      (_arbiter.speaking ? ambienceDuckedVolume : ambienceVolume) *
      masterVolume;

  void _duck(bool speaking) {
    if (!_ambiencePlaying) return;
    try {
      _ambience?.setVolume(_ambienceLevel());
    } catch (_) {}
  }

  Future<void> dispose() async {
    _arbiter.reset();
    _ambienceWanted = false;
    for (final p in [?_voice, ?_ambience]) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}

class _VoicePlayerOutput implements VoiceOutput {
  _VoicePlayerOutput(this._s);
  final AudioService _s;
  StreamSubscription<void>? _sub;

  AudioPlayer get _p =>
      _s._voice ??= _newPlayer()..setAudioContext(AudioService._context);

  @override
  Future<void> start(String asset, void Function() onFinished) async {
    final p = _p;
    await _sub?.cancel();
    _sub = p.onPlayerComplete.listen((_) => onFinished());
    try {
      await p.setVolume(_s.masterVolume);
      await p.play(AssetSource('$_sharedAudio$asset'));
    } catch (e) {
      debugPrint('audio: $asset failed: $e');
      onFinished();
    }
  }

  @override
  Future<Duration?> remaining() async {
    final p = _p;
    final d = await p.getDuration();
    final pos = await p.getCurrentPosition();
    if (d == null || pos == null) return null;
    return d - pos;
  }
}

/// One-shot player for the Settings "preview" button. Plays a track from the start, looping
/// until stopped; separate from the in-game [AudioService] so Settings needs no game audio.
class AmbiencePreview {
  AudioPlayer? _player;
  String? playing;

  Future<void> toggle(String id, double volume) async {
    if (playing == id) return stop();
    String? file;
    for (final t in ambienceTracks) {
      if (t.$1 == id) file = t.$3;
    }
    if (file == null) return stop();
    try {
      final p = _player ??= _newPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(AudioService.ambienceVolume * volume * 2);
      await p.play(AssetSource('${_sharedAudio}ambience/$file'));
      playing = id;
    } catch (e) {
      debugPrint('audio: preview $id failed: $e');
      playing = null;
    }
  }

  Future<void> stop() async {
    playing = null;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    playing = null;
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
