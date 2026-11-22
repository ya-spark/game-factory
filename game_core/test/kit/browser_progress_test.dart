import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ev = SkillEvidence(correct: true, day: 1, format: 'mcq');

TrailNode nodeFor(String key, SkillState s) => TrailNode(
  skill: Skill(
    id: 'frac_0',
    subject: 'maths',
    year: 7,
    topic: 'frac',
    name: 'R',
    seqFrom: 0,
    seqTo: 9,
    requires: const [],
    order: 0,
    rung: 0,
  ),
  state: s,
  openItems: 10,
  accuracy: null,
);

void main() {
  test('answers survive a reload', () async {
    final s = MemoryProgressStorage();
    final a = BrowserProgress(s);
    await a.load();
    await a.recordEvidence('maths/7/frac_0', ev, SkillRules.ranger);
    await a.recordBest('snake', 12);
    await a.recordBest('snake', 5);
    final b = BrowserProgress(s);
    await b.load();
    expect(b.progress.skills['maths/7/frac_0']!.evidence, hasLength(1));
    expect(b.bestScore('snake'), 12);
    expect(s.data.keys, containsAll(['amc.progress.v1', 'amc.best.snake']));
  });

  test('corrupt, newer-version and bad-rung data start safely', () async {
    final s = MemoryProgressStorage()..data['amc.progress.v1'] = '{nope';
    var p = BrowserProgress(s);
    await p.load();
    expect(p.progress.skills, isEmpty);
    expect(p.storageOk, isTrue);
    s.data['amc.progress.v1'] = '{"v":99,"skills":{"a":{}}}';
    p = BrowserProgress(s);
    await p.load();
    expect(p.progress.skills, isEmpty);
    s.data['amc.progress.v1'] = '{"v":1,"skills":{"a":{"e":[]},"b":5}}';
    p = BrowserProgress(s);
    await p.load();
    expect(p.progress.skills.keys, ['a']);
  });

  test('blocked storage: works in memory, never throws', () async {
    final s = MemoryProgressStorage()..blocked = true;
    final p = BrowserProgress(s);
    await p.load();
    await p.recordEvidence('k', ev, SkillRules.ranger);
    await p.recordBest('g', 3);
    expect(p.storageOk, isFalse);
    expect(p.progress.skills, hasLength(1));
    expect(p.bestScore('g'), 3);
    await p.clear();
    expect(p.progress.skills, isEmpty);
  });

  test('clear removes only amc progress keys', () async {
    final s = MemoryProgressStorage()..data['amc.theme'] = 'dark';
    final p = BrowserProgress(s);
    await p.recordEvidence('k', ev, SkillRules.ranger);
    await p.recordBest('g', 3);
    await p.clear();
    expect(s.data.keys, ['amc.theme']);
  });

  test('prefs storage round trip and Constellation stars', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = BrowserProgress(PrefsProgressStorage(prefs));
    await p.recordEvidence('maths/7/frac_0', ev, SkillRules.ranger);
    final p2 = BrowserProgress(PrefsProgressStorage(prefs));
    await p2.load();
    expect(p2.progress.skills, hasLength(1));
    // The saved state drives the stars the trail draws.
    final state = p2.progress.skills['maths/7/frac_0']!.stateOf(
      SkillRules.ranger,
      today: 1,
    );
    expect(state, SkillState.practising);
    expect(nodeFor('x', state).stars, 1);
  });
}
