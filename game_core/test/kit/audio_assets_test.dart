import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/kit/audio/audio.dart';

void main() {
  test('every ambience track has a file in assets/audio/ambience', () {
    for (final t in ambienceTracks) {
      if (t.$3 == null) continue;
      expect(
        File('assets/audio/ambience/${t.$3}').existsSync(),
        isTrue,
        reason: t.$3,
      );
    }
    expect(ambienceTracks.any((t) => t.$1 == defaultAmbienceId), isTrue);
  });

  test('every ambience file is listed in the licences', () {
    final lic = File('assets/LICENSES.md').readAsStringSync();
    for (final t in ambienceTracks) {
      if (t.$3 == null) continue;
      expect(
        lic.contains('assets/audio/ambience/${t.$3}'),
        isTrue,
        reason: t.$3,
      );
    }
  });

  test('a sound pack that is not owned falls back to the default track', () {
    expect(
      resolveAmbience('rain', owned: {}, packsEnabled: true),
      defaultAmbienceId,
    );
    expect(
      resolveAmbience('rain', owned: {'rain'}, packsEnabled: false),
      defaultAmbienceId,
    );
    expect(
      resolveAmbience('rain', owned: {'rain'}, packsEnabled: true),
      'rain',
    );
    expect(resolveAmbience('night', owned: {}, packsEnabled: false), 'night');
  });
}
