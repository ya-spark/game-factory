import 'dart:math';

import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item(String id, int seq, {String type = 'mcq'}) => {
  'id': id,
  'seq': seq,
  'difficulty': 1,
  'type': type,
  'explanation': 'because $id',
  'prompt': 'p $id',
  'options': ['a', 'b'],
  'correct': 0,
};

List<LoadedPack> packsOf(int n, {String topic = 't1', int year = 3}) => [
  LoadedPack(
    ContentPack({
      'id': 'm_$topic',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': year,
      'topic': topic,
      'title': 'm',
      'items': [for (var i = 1; i <= n; i++) _item('m_$topic.$i', i)],
    }),
  ),
];

List<PoolItem> poolOf(List<LoadedPack> packs) =>
    ReleaseEngine.ordered(packs, 'maths', 3);

QuizSession session(
  List<LoadedPack> packs, {
  ChildProgress progress = const ChildProgress(),
  // The learning challenges (new questions, new topic, revise) are tested in
  // learning_challenges_test.dart; here they pay nothing so the other coin rules stand alone.
  RewardsConfig cfg = const RewardsConfig(
    newQuestionsCoins: 0,
    newTopicCoins: 0,
    reviseCoins: 0,
  ),
  int today = 100,
  int streakDays = 0,
  List<PoolItem>? items,
}) => QuizSession(
  items: items ?? poolOf(packs),
  progress: progress,
  packs: packs,
  rewardsConfig: cfg,
  today: today,
  streakDays: streakDays,
);

void main() {
  group('standalone games', () {
    MiniGame standalone({List<int>? stars}) => MiniGame(
      id: 'solo',
      title: 'Solo',
      itemTypes: const {},
      build: (_) => Object(),
      buildStandalone: stars == null ? null : (_) => Object(),
      starScores: stars,
    );

    test('standalone is true only with buildStandalone', () {
      expect(standalone().standalone, isFalse);
      expect(standalone(stars: const [10]).standalone, isTrue);
    });

    test('starsForBest counts the thresholds reached, 0 when none', () {
      final g = standalone(stars: const [100, 300, 600]);
      expect(g.starsForBest(0), 0);
      expect(g.starsForBest(99), 0);
      expect(g.starsForBest(100), 1);
      expect(g.starsForBest(450), 2);
      expect(g.starsForBest(600), 3);
      expect(standalone().starsForBest(999), 0);
    });

    test('withAccess keeps the standalone fields', () {
      final g = standalone(stars: const [1, 2, 3])
          .withAccess(GameAccess.coins, 300);
      expect(g.standalone, isTrue);
      expect(g.starsForBest(2), 2);
      expect(g.coinPrice, 300);
    });

    test('a standalone game is offered without any pool, subject or year', () {
      final reg = MiniGameRegistry([
        RegistryEntry(standalone(stars: const [1])),
        RegistryEntry(
          MiniGame(
            id: 'quiz',
            title: 'Quiz',
            itemTypes: const {ItemType.mcq},
            build: (_) => Object(),
          ),
        ),
      ]);
      final offers = reg.offers(
        open: const [],
        subject: 'maths',
        year: 3,
        mode: MiniGameMode.game,
        unlocked: const {},
      );
      expect(offers.map((o) => o.game.id), ['solo']);
    });
  });

  group('QuizSession scoring', () {
    test('first pass earns a star; a repeat pass earns none', () {
      final packs = packsOf(10);
      final p = poolOf(packs).first;
      final s = session(packs, items: [p, p, p]);
      final a = s.answer(correct: true);
      expect(a.firstPass, isTrue);
      expect(a.stars, 1);
      expect(a.explanation, 'because ${p.id}');
      expect(s.answer(correct: true).stars, 0);
      // A wrong answer then a pass: the pass is still not a first pass.
      expect(s.answer(correct: false).stars, 0);
      expect(s.progress.rewards.stars, 1);
      expect(s.progress.items[p.id]!.passes, 2);
      expect(s.finished, isTrue);
      expect(s.report.answered, 3);
      expect(s.report.correct, 2);
      expect(s.report.stars, 1);
    });

    test('a wrong answer first earns nothing, the later pass earns a star', () {
      final packs = packsOf(10);
      final p = poolOf(packs).first;
      final s = session(packs, items: [p, p]);
      expect(s.answer(correct: false).stars, 0);
      expect(s.answer(correct: true).stars, 1);
    });

    test('topic bonus once, when the last item of the topic is passed', () {
      final packs = packsOf(3);
      final s = session(packs);
      expect(s.answer(correct: true).stars, 1);
      expect(s.answer(correct: true).stars, 1);
      final last = s.answer(correct: true);
      expect(last.topicCompleted, isTrue);
      expect(last.stars, 1 + 5);
      expect(last.coins, 10);
      // Playing the topic again pays nothing more.
      final again = session(packs, progress: s.progress);
      expect(again.answer(correct: true).stars, 0);
      expect(again.progress.rewards.paid, contains('topic:maths/3/t1'));
    });

    test('streak bonus stars once a day from a 2 day streak', () {
      final packs = packsOf(10);
      final s = session(packs, streakDays: 2);
      expect(s.answer(correct: true).stars, 1 + 2);
      expect(s.answer(correct: true).stars, 1);
      final s1 = session(packs, streakDays: 1);
      expect(s1.answer(correct: true).stars, 1);
      final nextDay = session(
        packs,
        progress: s.progress,
        today: 101,
        streakDays: 3,
        items: poolOf(packs).sublist(2),
      );
      expect(nextDay.answer(correct: true).stars, 1 + 2);
    });

    test('a streak milestone pays coins once', () {
      final packs = packsOf(10);
      final s = session(packs, streakDays: 3);
      expect(s.answer(correct: true).coins, 10);
      expect(s.answer(correct: true).coins, 0);
      final later = session(
        packs,
        progress: s.progress,
        today: 101,
        streakDays: 3,
        items: poolOf(packs).sublist(2),
      );
      expect(later.answer(correct: true).coins, 0);
    });

    test('daily and weekly goals pay once each', () {
      final packs = packsOf(40);
      var progress = const ChildProgress();
      var coins = 0;
      final all = poolOf(packs);
      for (var day = 95; day < 98; day++) {
        // Days 95..101 are one week (Monday 95).
        final s = session(
          packs,
          progress: progress,
          today: day,
          items: all.sublist((day - 95) * 9, (day - 95) * 9 + 9),
        );
        while (!s.finished) {
          coins += s.answer(correct: true).coins;
        }
        progress = s.progress;
      }
      // 3 days x 5 coins (daily goal) + 15 (weekly goal at 25 passes) = 30, below the cap.
      expect(coins, 30);
      expect(progress.rewards.coinsThisWeek(95), 30);
    });

    test('weekly coin cap is per child and resets next week', () {
      const cfg = RewardsConfig(
        weeklyCapPerChild: 12,
        topicCoins: 10,
        dailyGoalItems: 1,
        dailyGoalCoins: 5,
      );
      final packs = packsOf(1);
      int play(ChildProgress p, int day) {
        final s = session(packs, progress: p, cfg: cfg, today: day);
        final c = s.answer(correct: true).coins;
        lastProgress = s.progress;
        return c;
      }

      // Topic done (10) + daily goal (5) = 15, cut to 12.
      expect(play(const ChildProgress(), 100), 12);
      final childA = lastProgress;
      expect(childA.rewards.coinsThisWeek(100), 12);
      // Another child has an own cap.
      expect(play(const ChildProgress(), 100), 12);
      // A different week pays again (daily goal 5; the topic bonus was already paid).
      final packs2 = packsOf(1, topic: 't2');
      final s = session(packs2, progress: childA, cfg: cfg, today: 110);
      expect(s.answer(correct: true).coins, 12);
    });

    test('grantCapped cuts other earners to the cap', () {
      const cfg = RewardsConfig(weeklyCapPerChild: 60);
      var st = const RewardState();
      final a = RewardsEngine.grantCapped(st, 50, 100, cfg);
      expect(a.coins, 50);
      st = a.state;
      final b = RewardsEngine.grantCapped(st, 50, 101, cfg);
      expect(b.coins, 10);
      expect(RewardsEngine.grantCapped(b.state, 5, 101, cfg).coins, 0);
      expect(RewardsEngine.grantCapped(b.state, 5, 110, cfg).coins, 5);
    });

    test('no stars in Mind hubs (stars disabled)', () {
      const cfg = RewardsConfig(starsEnabled: false);
      final packs = packsOf(3);
      final s = session(packs, cfg: cfg);
      expect(s.answer(correct: true).stars, 0);
      expect(s.answer(correct: true).stars, 0);
      expect(s.answer(correct: true).stars, 0);
      expect(s.progress.rewards.stars, 0);
    });

    test('progress with rewards survives JSON', () {
      final packs = packsOf(3);
      final s = session(packs, streakDays: 3);
      while (!s.finished) {
        s.answer(correct: true);
      }
      final back = ChildProgress.fromJson(s.progress.toJson());
      expect(back.rewards.stars, s.progress.rewards.stars);
      expect(back.rewards.paid, s.progress.rewards.paid);
      expect(back.rewards.weekCoins, s.progress.rewards.weekCoins);
      expect(ChildProgress.fromJson(null).rewards.stars, 0);
    });

    test('start() needs the minimum pool', () {
      final packs = packsOf(3);
      QuizSession? go(int minPool) => QuizSession.start(
        open: poolOf(packs),
        progress: const ChildProgress(),
        packs: packs,
        rewardsConfig: const RewardsConfig(),
        subject: 'maths',
        year: 3,
        today: 100,
        random: Random(1),
        minPool: minPool,
      );
      expect(go(4), isNull);
      expect(go(3)!.total, 3);
    });
  });

  group('access rules', () {
    MiniGame game(String id, {GameAccess a = GameAccess.freeWithAds}) =>
        MiniGame(
          id: id,
          title: id,
          itemTypes: const {ItemType.mcq},
          minPool: 4,
          access: a,
          coinPrice: 200,
          modes: const {MiniGameMode.game},
          build: (_) => Object(),
        );

    final packs = packsOf(6);
    final open = poolOf(packs);

    test('free and coin-locked games, price shown, gated by pool and mode', () {
      final reg = MiniGameRegistry([
        RegistryEntry(game('free')),
        RegistryEntry(game('paid', a: GameAccess.coins)),
        RegistryEntry(game('study_only'), modes: const {MiniGameMode.study}),
        RegistryEntry(game('older'), minYear: 5),
      ]);
      final offers = reg.offers(
        open: open,
        subject: 'maths',
        year: 3,
        mode: MiniGameMode.game,
        unlocked: {},
      );
      expect([for (final o in offers) o.game.id], ['free', 'paid']);
      expect(offers[0].locked, isFalse);
      expect(offers[0].price, 0);
      expect(offers[1].locked, isTrue);
      expect(offers[1].price, 200);
      final unlocked = reg.offers(
        open: open,
        subject: 'maths',
        year: 3,
        mode: MiniGameMode.game,
        unlocked: {'paid'},
      );
      expect(unlocked[1].locked, isFalse);
      // Not enough open items: nothing appears.
      expect(
        reg.offers(
          open: open.take(3).toList(),
          subject: 'maths',
          year: 3,
          mode: MiniGameMode.game,
          unlocked: {},
        ),
        isEmpty,
      );
    });

    test('only counts items of the game types towards the pool', () {
      final reg = MiniGameRegistry([RegistryEntry(game('free'))]);
      final numeric = LoadedPack(
        ContentPack({
          'id': 'n',
          'version': 1,
          'lang': 'en-AU',
          'subject': 'maths',
          'year': 3,
          'topic': 't',
          'title': 'n',
          'items': [
            for (var i = 1; i <= 8; i++) _item('n.$i', i, type: 'numeric'),
          ],
        }),
      );
      expect(
        reg.offers(
          open: poolOf([numeric]),
          subject: 'maths',
          year: 3,
          mode: MiniGameMode.game,
          unlocked: {},
        ),
        isEmpty,
      );
    });

    test('tryUnlock spends coins once and is permanent', () {
      final g = game('paid', a: GameAccess.coins);
      final no = MiniGameRegistry.tryUnlock(g, {}, 199);
      expect(no.ok, isFalse);
      expect(no.coins, 199);
      expect(no.unlocked, isEmpty);
      final yes = MiniGameRegistry.tryUnlock(g, {}, 250);
      expect(yes.ok, isTrue);
      expect(yes.coins, 50);
      expect(yes.unlocked, {'paid'});
      final again = MiniGameRegistry.tryUnlock(g, yes.unlocked, yes.coins);
      expect(again.coins, 50);
      expect(MiniGameRegistry.tryUnlock(game('f'), {}, 0).ok, isTrue);
    });

    test(
      'ProfileStore keeps the unlock across restarts and spends coins',
      () async {
        final saves = MemorySaveService();
        final now = DateTime(2026, 3, 1, 10);
        ProfileStore make() => ProfileStore(
          saves: saves,
          retention: const RetentionConfig(),
          clock: () => now,
        );
        final p = make();
        await p.init();
        expect(await p.unlockGame('paid', 200), isFalse);
        await p.addCoins(250);
        expect(await p.unlockGame('paid', 200), isTrue);
        expect(p.data.coins, 50);
        expect(await p.unlockGame('paid', 200), isTrue);
        expect(p.data.coins, 50);
        final q = make();
        await q.init();
        expect(q.isGameUnlocked('paid'), isTrue);
        expect(q.data.coins, 50);
      },
    );
  });

  test('NoAiTutorService is never available and never answers', () async {
    const ai = NoAiTutorService();
    expect(ai.isAvailable, isFalse);
    await expectLater(ai.explain('x'), throwsUnsupportedError);
  });

  test('template config: rewards, minigames and ai defaults', () {
    final c = AppConfig.fromYamlString('''
app: {id: a, display_name: A, package_name: com.x.a}
admob:
  debug: {app_id: x, banner: x, interstitial: x, rewarded: x}
  release: {app_id: x, banner: x, interstitial: x, rewarded: x}
rewards:
  stars: {enabled: false, topic_bonus: 7}
  coins: {weekly_cap_per_child: 30, streak_milestones: {5: 12}}
minigames: {coin_price: 300}
''');
    expect(c.rewards.starsEnabled, isFalse);
    expect(c.rewards.topicBonus, 7);
    expect(c.rewards.perFirstPass, 1);
    expect(c.rewards.weeklyCapPerChild, 30);
    expect(c.rewards.streakMilestones, {5: 12});
    expect(c.minigames.coinPrice, 300);
    expect(c.aiEnabled, isFalse);
    final d = AppConfig.fromYamlString('''
app: {id: a, display_name: A, package_name: com.x.a}
admob:
  debug: {app_id: x, banner: x, interstitial: x, rewarded: x}
  release: {app_id: x, banner: x, interstitial: x, rewarded: x}
''');
    expect(d.rewards.weeklyCapPerChild, 60);
    expect(d.minigames.coinPrice, 200);
  });
}

ChildProgress lastProgress = const ChildProgress();
