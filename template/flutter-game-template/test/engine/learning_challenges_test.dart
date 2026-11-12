import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item(String id, int seq) => {
  'id': id,
  'seq': seq,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'because $id',
  'prompt': 'p $id',
  'options': ['a', 'b'],
  'correct': 0,
};

List<LoadedPack> _packs(int n, String topic) => [
  LoadedPack(
    ContentPack({
      'id': 'm_$topic',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': 3,
      'topic': topic,
      'title': 'm',
      'items': [for (var i = 1; i <= n; i++) _item('m_$topic.$i', i)],
    }),
  ),
];

QuizSession _session(
  List<LoadedPack> packs,
  List<PoolItem> items,
  ChildProgress progress,
  int today,
) => QuizSession(
  items: items,
  progress: progress,
  packs: packs,
  rewardsConfig: const RewardsConfig(),
  today: today,
  streakDays: 0,
);

void main() {
  const cfg = RewardsConfig();

  group('RewardsEngine.onAnswer', () {
    test('new topic pays once a day, then again the next day', () {
      var g = RewardsEngine.onAnswer(
        const RewardState(),
        cfg,
        day: 10,
        newTopic: true,
        revised: false,
      );
      expect(g.coins, cfg.newTopicCoins);
      expect(g.state.todayNewTopics, 1);
      g = RewardsEngine.onAnswer(
        g.state,
        cfg,
        day: 10,
        newTopic: true,
        revised: false,
      );
      expect(g.coins, 0, reason: 'no double payout');
      g = RewardsEngine.onAnswer(
        g.state,
        cfg,
        day: 11,
        newTopic: true,
        revised: false,
      );
      expect(g.coins, cfg.newTopicCoins);
      expect(g.state.todayNewTopics, 1, reason: 'counter reset daily');
    });

    test('revise pays after N mistakes put right, once a day', () {
      var s = const RewardState();
      var total = 0;
      for (var i = 0; i < cfg.reviseGoal + 2; i++) {
        final g = RewardsEngine.onAnswer(
          s,
          cfg,
          day: 10,
          newTopic: false,
          revised: true,
        );
        s = g.state;
        total += g.coins;
        if (i < cfg.reviseGoal - 1) expect(g.coins, 0);
      }
      expect(total, cfg.reviseCoins);
    });

    test('the weekly cap still applies', () {
      const capped = RewardsConfig(weeklyCapPerChild: 3);
      final g = RewardsEngine.onAnswer(
        const RewardState(),
        capped,
        day: 10,
        newTopic: true,
        revised: false,
      );
      expect(g.coins, 3);
    });

    test('state survives json, and old saves read as zero', () {
      const s = RewardState(todayNewTopics: 1, todayRevised: 2);
      final back = RewardState.fromJson(s.toJson());
      expect(back.todayNewTopics, 1);
      expect(back.todayRevised, 2);
      expect(RewardState.fromJson(const {'s': 4}).todayRevised, 0);
    });
  });

  group('QuizSession feeds the learning challenges', () {
    test('first answer in a topic is a new topic, later ones are not', () {
      final packs = _packs(10, 't1');
      final pool = ReleaseEngine.ordered(packs, 'maths', 3);
      final s = _session(
        packs,
        pool.take(2).toList(),
        const ChildProgress(),
        5,
      );
      s.answer(correct: false);
      expect(s.progress.rewards.todayNewTopics, 1);
      s.answer(correct: true);
      expect(s.progress.rewards.todayNewTopics, 1);
    });

    test('pass N new questions pays once; a repeat does not count', () {
      final packs = _packs(10, 't1');
      final pool = ReleaseEngine.ordered(packs, 'maths', 3);
      final items = [...pool.take(4), pool.first];
      final s = _session(packs, items, const ChildProgress(), 5);
      var coins = 0;
      for (var i = 0; i < 5; i++) {
        coins += s.answer(correct: true).coins;
      }
      expect(coins, cfg.newTopicCoins + cfg.newQuestionsCoins);
      expect(s.progress.rewards.todayPasses, 4);
    });

    test('revise counts right after wrong, not a first try', () {
      final packs = _packs(10, 't1');
      final pool = ReleaseEngine.ordered(packs, 'maths', 3);
      final a = pool[0];
      final b = pool[1];
      final s = _session(packs, [a, b, a], const ChildProgress(), 5);
      s.answer(correct: false);
      s.answer(correct: true);
      expect(s.progress.rewards.todayRevised, 0);
      s.answer(correct: true);
      expect(s.progress.rewards.todayRevised, 1);
    });

    test('counters reset on a new day', () {
      final packs = _packs(10, 't1');
      final pool = ReleaseEngine.ordered(packs, 'maths', 3);
      final s = _session(packs, [pool[0]], const ChildProgress(), 5);
      s.answer(correct: true);
      final s2 = _session(packs, [pool[1]], s.progress, 6);
      s2.answer(correct: true);
      expect(s2.progress.rewards.todayPasses, 1);
      expect(s2.progress.rewards.todayNewTopics, 0);
    });
  });
}
