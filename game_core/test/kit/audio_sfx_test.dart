import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/kit/audio/audio.dart';

void main() {
  test('effects play only with Sound and effects both on', () async {
    final a = FakeAudioService();
    a.apply(sound: true, volume: 1, ambience: 'off', voice: true);
    await a.sfx('tap');
    a.apply(sound: true, volume: 1, ambience: 'off', voice: true, sfx: false);
    await a.sfx('skipped');
    a.apply(sound: false, volume: 1, ambience: 'off', voice: true);
    await a.sfx('muted');
    expect(a.sfxes, ['tap']);
  });

  test(
    'a service without an effects folder plays no effects and never throws',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final a = AudioplayersAudioService();
      a.apply(sound: true, volume: 1, ambience: 'off', voice: true);
      await a.sfx('tap');
      await a.dispose();
    },
  );

  test('a game can offer its own background sounds', () {
    final a = AudioplayersAudioService(
      tracks: const [('off', 'Off', null), ('night', 'Night', 'night.mp3')],
      defaultAmbience: 'night',
    );
    expect(a.ambienceId, 'night');
    expect(AmbiencePreview(tracks: const []).playing, isNull);
  });
}
