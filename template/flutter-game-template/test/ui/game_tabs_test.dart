import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/app_shell.dart';
import 'package:flutter_game_template/ui/kit/ds_art.dart';
import 'package:flutter_game_template/ui/kit/ds_cards.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

PoolItem _item(String id, String subject, int year) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': 'mcq',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b'],
    'correct': 0,
  }),
  packId: 'pk',
  subject: subject,
  year: year,
  topic: 'Fractions',
);

MiniGame _game(String id, {int price = 0}) => MiniGame(
  id: id,
  title: 'Game $id',
  itemTypes: const {ItemType.mcq},
  access: price > 0 ? GameAccess.coins : GameAccess.freeWithAds,
  coinPrice: price,
  build: (_) => const SizedBox(),
);

final _registry = MiniGameRegistry([
  RegistryEntry(_game('free')),
  RegistryEntry(_game('paid', price: 80)),
]);

TabLoaders _loaders(int open) => TabLoaders(
  openItems: (_) async => [
    for (var i = 0; i < open; i++) _item('i$i', 'maths', 3),
  ],
  packs: () async => const [],
);

Future<Services> _pump(
  WidgetTester tester,
  String id, {
  int open = 6,
  int coins = 0,
  LearnMode mode = LearnMode.game,
}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5; // 150 percent text
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final s = await buildFakeServices(contentEnabled: true);
  if (coins > 0) await s.profile.addCoins(coins);
  final kid = (await s.profile.addChild('Mia', year: 3))!;
  await s.profile.setChildMode(kid.id, mode);
  s.profile.selectChild(kid.id);
  final design = loadDesign(id);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: FileDesignBundle(),
      child: ServicesScope(
        services: s,
        child: MaterialApp(
          theme: buildDesignTheme(
            app: design.app,
            shared: design.shared,
            mode: design.app.modes.keys.first,
            level: design.app.levelForYear(3),
          ),
          builder: (context, child) => DesignScope(
            design: design,
            mode: design.app.modes.keys.first,
            level: design.app.levelForYear(3),
            child: child!,
          ),
          home: AppShell(registry: _registry, loaders: _loaders(open)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

Finder _tab(String id) => find.byKey(TestIds.dsTab(TestIds.shellBottomBar, id));

void main() {
  for (final id in appIds) {
    testWidgets(
      '$id: Play lists registry games, locked ones show their price',
      (tester) async {
        await _pump(tester, id);
        expect(find.byKey(TestIds.playTab), findsOneWidget);
        expect(find.byKey(TestIds.playGame('free')), findsOneWidget);
        expect(find.byKey(TestIds.playGame('paid')), findsOneWidget);
        expect(
          find.byKey(TestIds.playTryNext),
          findsNothing,
        ); // key is on the card below
        expect(find.byKey(TestIds.dsSuggestedCard('next')), findsOneWidget);
        expect(find.byKey(TestIds.playDaily), findsOneWidget);
        // Each game shows once (the daily game is a badge, not a second tile).
        expect(find.byType(DsGameTile), findsNWidgets(2));
        expect(find.byType(DsGameArt), findsNWidgets(2));
        // The coin price is on the locked game's tile and it is read out.
        expect(find.byKey(TestIds.dsCoinChip('price.paid')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('locked, 80 coins')), findsWidgets);
        // No money anywhere on the page.
        expect(find.textContaining(RegExp(r'[$£€]')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$id: games show only when enough items are open', (
      tester,
    ) async {
      await _pump(tester, id, open: 3);
      expect(find.byKey(TestIds.playGame('free')), findsNothing);
      expect(find.byKey(TestIds.playGame('paid')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$id: a locked game opens with coins', (tester) async {
      final s = await _pump(tester, id, coins: 100);
      await tester.ensureVisible(find.byKey(TestIds.playGame('paid')));
      await tester.tap(find.byKey(TestIds.playGame('paid')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TestIds.dsButton('unlock.paid.primary')));
      await tester.pumpAndSettle();
      expect(s.profile.isGameUnlocked('paid'), isTrue);
      expect(s.profile.data.coins, 20);
    });

    testWidgets('$id: Challenges and Shop build, no overflow, no money price', (
      tester,
    ) async {
      final s = await _pump(tester, id, coins: 60);
      await tester.tap(_tab('challenges'));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.challengesTab), findsOneWidget);
      expect(find.byKey(TestIds.challengeGoal('daily')), findsOneWidget);
      expect(find.byKey(TestIds.challengeGoal('streak')), findsOneWidget);
      // Only learning goals: none of the old block puzzle challenges.
      expect(
        find.textContaining(RegExp('combo|lines|points in one game')),
        findsNothing,
      );
      expect(find.textContaining('Place '), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(_tab('shop'));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.shopTab), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(TestIds.shopGame('paid')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(TestIds.shopGame('paid')), findsOneWidget);
      expect(find.textContaining(RegExp(r'[$£€]')), findsNothing);
      // Buy an avatar with coins: coins drop, the avatar is in use.
      await tester.scrollUntilVisible(
        find.byKey(TestIds.shopAvatar('cat')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(TestIds.dsButton('shop.use.cat')));
      await tester.pumpAndSettle();
      expect(s.profile.activeChild!.avatar, 'cat');
      expect(s.profile.data.coins, 20);
      expect(tester.takeException(), isNull);
    });
  }
}
