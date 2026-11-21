import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_service.dart';
import 'voice_arbiter.dart';

/// Narrator voice and ambience are package assets of game_core: the bundle key carries
/// `packages/game_core/assets/audio/`, so every player uses an [AudioCache] with no prefix (the
/// default cache would look in the app's own `assets/`).
const String _audioBase = 'packages/game_core/assets/audio/';
final AudioCache _cache = AudioCache(prefix: '');
AudioPlayer _newPlayer() => AudioPlayer()..audioCache = _cache;

/// [AudioService] over `audioplayers`. The only file that imports it. Failures (missing
/// plugin in tests, no audio device) are swallowed: sound is never worth crashing a game.
class AudioplayersAudioService implements AudioService {
  /// [tracks] and [defaultAmbience] let a game offer its own background sounds (default: the shared
  /// list). [sfxBase] is the bundle key prefix of the game's own assets, for example
  /// `packages/game_wingy/assets/`: effects play `<sfxBase>sfx/<name>.wav`; without it [sfx] does nothing.
  AudioplayersAudioService({
    Random? random,
    List<(String, String, String?)>? tracks,
    String? defaultAmbience,
    this.sfxBase,
  }) : _random = random ?? Random(),
       _tracks = tracks ?? ambienceTracks,
       ambienceId = defaultAmbience ?? defaultAmbienceId {
    _arbiter = VoiceArbiter(_VoicePlayerOutput(this), onSpeaking: _duck);
  }

  final Random _random;
  final List<(String, String, String?)> _tracks;
  final String? sfxBase;
  final List<AudioPlayer> _sfx = [];
  int _nextSfx = 0;
  AudioPlayer? _voice;
  AudioPlayer? _ambience;
  late final VoiceArbiter _arbiter;

  bool enabled = true;
  bool voiceOn = true;
  double masterVolume = 1.0;
  bool sfxOn = true;
  String ambienceId;

  bool _ambienceWanted = false;
  bool _ambiencePlaying = false;
  String? _ambienceLoaded;

  static const int _sfxChannels = 4;
  static const double sfxVolume = 0.7;
  static const double ambienceVolume = 0.25;
  static const double ambienceDuckedVolume = 0.1;

  /// Voice and ambience never take Android audio focus, so they cannot interrupt each other
  /// (or other apps' audio).
  static final AudioContext _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  @override
  void apply({
    required bool sound,
    required double volume,
    required String ambience,
    required bool voice,
    bool sfx = true,
  }) {
    sfxOn = sfx;
    enabled = sound;
    masterVolume = volume;
    voiceOn = voice;
    if (ambience != ambienceId) {
      ambienceId = ambience;
      _ambienceLoaded = null;
    }
    unawaited(_syncAmbience());
  }

  /// Plays `sfx/<name>.wav`; overlapping effects use a small round-robin pool.
  @override
  Future<void> sfx(String name) async {
    final base = sfxBase;
    if (base == null || !enabled || !sfxOn) return;
    final p = _sfxPlayer();
    try {
      await p.stop();
      await p.setVolume(sfxVolume * masterVolume);
      await p.play(AssetSource('${base}sfx/$name.wav'));
    } catch (e) {
      debugPrint('audio: sfx/$name failed: $e');
    }
  }

  AudioPlayer _sfxPlayer() {
    if (_sfx.length < _sfxChannels) {
      final p = _newPlayer()..setAudioContext(_context);
      _sfx.add(p);
      return p;
    }
    return _sfx[_nextSfx++ % _sfxChannels];
  }

  @override
  Future<void> voice(String name, {int variants = 1}) async {
    if (!enabled || !voiceOn) return;
    final n = variants <= 1 ? 1 : _random.nextInt(variants) + 1;
    final file = n == 1 ? name : '${name}_${n.toString().padLeft(2, '0')}';
    try {
      await _arbiter.say('${_audioBase}voice/$file.mp3', voicePriorityOf(name));
    } catch (e) {
      debugPrint('audio: voice/$file failed: $e');
    }
  }

  @override
  Future<void> startAmbience() {
    _ambienceWanted = true;
    return _syncAmbience();
  }

  @override
  Future<void> pauseAmbience() {
    _ambienceWanted = false;
    return _syncAmbience();
  }

  Future<void> _syncAmbience() async {
    String? file;
    for (final t in _tracks) {
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
        await pl.play(AssetSource('${_audioBase}ambience/$file'));
      } else if (!_ambiencePlaying) {
        await pl.resume();
      }
      _ambiencePlaying = true;
    } catch (e) {
      debugPrint('audio: ambience failed: $e');
    }
  }

  AudioPlayer? _preview;
  Timer? _previewTimer;

  @override
  Future<void> previewAmbience(String id) async {
    String? file;
    for (final t in _tracks) {
      if (t.$1 == id) file = t.$3;
    }
    if (!enabled || file == null) return;
    try {
      _previewTimer?.cancel();
      final pl = _preview ??= _newPlayer()..setAudioContext(_context);
      await pl.setReleaseMode(ReleaseMode.loop);
      await pl.setVolume(ambienceVolume * 2 * masterVolume);
      await pl.play(AssetSource('${_audioBase}ambience/$file'));
      _previewTimer = Timer(ambiencePreviewLength, stopPreview);
    } catch (e) {
      debugPrint('audio: preview $id failed: $e');
    }
  }

  @override
  Future<void> stopPreview() async {
    _previewTimer?.cancel();
    try {
      await _preview?.stop();
    } catch (_) {}
  }

  /// The ambience is quieter while the voice speaks.
  double _ambienceLevel() =>
      (_arbiter.speaking ? ambienceDuckedVolume : ambienceVolume) *
      masterVolume;

  void _duck(bool speaking) {
    if (!_ambiencePlaying) return;
    try {
      _ambience?.setVolume(_ambienceLevel());
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _arbiter.reset();
    _ambienceWanted = false;
    _previewTimer?.cancel();
    for (final p in [..._sfx, ?_voice, ?_ambience, ?_preview]) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}

class _VoicePlayerOutput implements VoiceOutput {
  _VoicePlayerOutput(this._s);
  final AudioplayersAudioService _s;
  StreamSubscription<void>? _sub;

  AudioPlayer get _p =>
      _s._voice ??= _newPlayer()
        ..setAudioContext(AudioplayersAudioService._context);

  @override
  Future<void> start(String asset, void Function() onFinished) async {
    final p = _p;
    await _sub?.cancel();
    _sub = p.onPlayerComplete.listen((_) => onFinished());
    try {
      await p.setVolume(_s.masterVolume);
      await p.play(AssetSource(asset));
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

/// One-shot player for a Settings "preview" button: plays a track from the start, looping until
/// stopped. Separate from the in-game service so Settings needs no game audio.
class AmbiencePreview {
  AmbiencePreview({List<(String, String, String?)>? tracks})
    : _tracks = tracks ?? ambienceTracks;

  final List<(String, String, String?)> _tracks;
  AudioPlayer? _player;
  String? playing;

  Future<void> toggle(String id, double volume) async {
    if (playing == id) return stop();
    String? file;
    for (final t in _tracks) {
      if (t.$1 == id) file = t.$3;
    }
    if (file == null) return stop();
    try {
      final p = _player ??= _newPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(AudioplayersAudioService.ambienceVolume * volume * 2);
      await p.play(AssetSource('${_audioBase}ambience/$file'));
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
