/// Priority of a narrator line. A clip that is speaking is never stopped.
enum VoicePriority { high, normal, low }

/// Priority of each voice line (see docs/SPEC.md, Sound).
VoicePriority voicePriorityOf(String name) => switch (name) {
  'game_over' || 'better_than_the_best' => VoicePriority.high,
  'get_ready' || 'go' || 'careful' => VoicePriority.low,
  _ => VoicePriority.normal,
};

/// Plays one clip at a time; implemented over an audio player (fake in tests).
abstract class VoiceOutput {
  /// Starts [asset]; [onFinished] must be called when the clip ends.
  Future<void> start(String asset, void Function() onFinished);

  /// Time left in the current clip, or null when unknown.
  Future<Duration?> remaining();
}

/// Decides which voice line plays so none is cut off:
/// - nothing speaking: play now;
/// - high line while speaking: wait, play after the clip (newest waiting high wins);
/// - normal/low line while speaking: wait only if the clip ends within [grace], else drop.
class VoiceArbiter {
  VoiceArbiter(this._out, {this.onSpeaking});

  static const Duration grace = Duration(seconds: 1);

  final VoiceOutput _out;
  final void Function(bool speaking)? onSpeaking;
  bool _speaking = false;
  ({String asset, VoicePriority priority})? _pending;

  bool get speaking => _speaking;

  Future<void> say(String asset, VoicePriority priority) async {
    if (!_speaking) return _start(asset);
    if (priority != VoicePriority.high) {
      final left = await _out.remaining();
      if (!_speaking) return say(asset, priority);
      if (left == null || left > grace) return; // dropped
    }
    final p = _pending;
    if (p != null &&
        p.priority == VoicePriority.high &&
        priority != VoicePriority.high) {
      return; // a waiting high line beats a normal/low one
    }
    _pending = (asset: asset, priority: priority);
  }

  Future<void> _start(String asset) async {
    _speaking = true;
    onSpeaking?.call(true);
    await _out.start(asset, _finished);
  }

  void _finished() {
    final next = _pending;
    _pending = null;
    if (next != null) {
      _start(next.asset);
    } else {
      _speaking = false;
      onSpeaking?.call(false);
    }
  }

  /// Forget everything (screen left).
  void reset() {
    _pending = null;
    _speaking = false;
  }
}
