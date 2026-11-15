import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an older save loads with no seen games and keeps what is stored', () {
    final data = SaveData.fromJson(
      SaveMigrator.migrate({
        ...const SaveData().toJson(),
        'profiles': [
          {'id': 'a', 'nickname': 'Mia'},
        ],
      }),
    );
    expect(data.profiles.single.rulesSeen, isEmpty);
    // The previous save version migrates up to the current one.
    final prev = {...data.toJson(), 'version': SaveData.currentVersion - 1};
    final m = SaveMigrator.migrate(prev);
    expect(m['version'], SaveData.currentVersion);
    expect(SaveData.fromJson(m).profiles.single.rulesSeen, isEmpty);
    final withSeen = data.copyWith(
      profiles: [
        data.profiles.single.copyWith(rulesSeen: {'sort_bins'}),
      ],
    );
    final round = SaveData.fromJson(SaveMigrator.migrate(withSeen.toJson()));
    expect(round.profiles.single.rulesSeen, {'sort_bins'});
  });

  test('rulesSeen survives a profile JSON round trip and ignores junk', () {
    const p = ChildProfile(id: 'a', nickname: 'Mia', rulesSeen: {'b', 'a'});
    expect(p.toJson()['rulesSeen'], ['a', 'b']);
    final back = ChildProfile.fromJson({
      ...p.toJson(),
      'rulesSeen': ['x', 3],
    });
    expect(back.rulesSeen, {'x'});
  });
}
