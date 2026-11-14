import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

void main() {
  test('a version 8 save migrates with no exams and no extra time', () {
    final d = SaveData.fromJson(
      SaveMigrator.migrate({
        'version': 8,
        'profiles': [
          {'id': 'p1', 'nickname': 'Mia'},
        ],
      }),
    );
    expect(SaveData.currentVersion, 9);
    expect(d.profiles.single.exams.records, isEmpty);
    expect(d.profiles.single.extraTime, ExtraTime.none);
  });

  test('exam history (last 10) and extra time survive a round trip', () async {
    final s = await buildFakeServices(contentEnabled: true);
    final c = (await s.profile.addChild('Mia'))!;
    await s.profile.setExtraTime(c.id, ExtraTime.quarter);
    for (var i = 0; i < 12; i++) {
      await s.profile.recordExam(
        c.id,
        const ChildProgress(),
        ExamRecord(
          day: i,
          subject: 'maths',
          questions: 10,
          correct: i % 11,
          seconds: 100,
        ),
      );
    }
    final back = SaveData.fromJson(
      SaveMigrator.migrate(s.profile.data.toJson()),
    );
    final p = back.profiles.single;
    expect(p.extraTime, ExtraTime.quarter);
    expect(p.exams.records, hasLength(10));
    expect(p.exams.records.first.day, 2);
    expect(p.exams.records.last.day, 11);
  });
}
