import 'package:flutter_game_template/core/audio/voice_arbiter.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVoice implements VoiceOutput {
  final List<String> played = [];
  void Function()? _done;
  Duration left = const Duration(seconds: 3);

  @override
  Future<void> start(String asset, void Function() onFinished) async {
    played.add(asset);
    _done = onFinished;
  }

  @override
  Future<Duration?> remaining() async => left;

  void finish() => _done?.call();
}

void main() {
  test('priorities', () {
    for (final n in highPriorityVoiceLines) {
      expect(voicePriorityOf(n), VoicePriority.high, reason: n);
    }
    for (final n in lowPriorityVoiceLines) {
      expect(voicePriorityOf(n), VoicePriority.low, reason: n);
    }
    expect(voicePriorityOf('some_praise'), VoicePriority.normal);
  });

  test('a high line waits for a playing clip and plays after it', () async {
    final out = FakeVoice();
    final a = VoiceArbiter(out);
    await a.say('praise', VoicePriority.normal);
    await a.say('game_over', VoicePriority.high);
    expect(out.played, ['praise']);
    out.finish();
    expect(out.played, ['praise', 'game_over']);
    out.finish();
    expect(a.speaking, isFalse);
  });

  test('newest waiting high line wins', () async {
    final out = FakeVoice();
    final a = VoiceArbiter(out);
    await a.say('praise', VoicePriority.normal);
    await a.say('game_over', VoicePriority.high);
    await a.say('new_best', VoicePriority.high);
    out.finish();
    expect(out.played, ['praise', 'new_best']);
  });

  test('a normal line is dropped while another is speaking', () async {
    final out = FakeVoice();
    final a = VoiceArbiter(out);
    await a.say('one', VoicePriority.normal);
    await a.say('two', VoicePriority.normal);
    out.finish();
    expect(out.played, ['one']);
    expect(a.speaking, isFalse);
  });

  test(
    'a normal line within 1 s of the end waits; high pending beats it',
    () async {
      final out = FakeVoice()..left = const Duration(milliseconds: 800);
      final a = VoiceArbiter(out);
      await a.say('one', VoicePriority.normal);
      await a.say('go', VoicePriority.low);
      out.finish();
      expect(out.played, ['one', 'go']);
      await a.say('game_over', VoicePriority.high);
      await a.say('two', VoicePriority.normal);
      out.finish();
      expect(out.played, ['one', 'go', 'game_over']);
    },
  );

  test('onSpeaking reports start and end (ambience ducking)', () async {
    final out = FakeVoice();
    final states = <bool>[];
    final a = VoiceArbiter(out, onSpeaking: states.add);
    await a.say('one', VoicePriority.normal);
    out.finish();
    expect(states, [true, false]);
  });
}
