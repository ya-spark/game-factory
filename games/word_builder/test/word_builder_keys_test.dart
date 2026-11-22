import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_word_builder/word_builder.dart';

Map<String, dynamic> _word(int i, String answer) => {
  'id': 'w.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'Word explained $i',
  'answer': answer,
  'hint': 'Hint $i',
};

Map<String, dynamic> _cloze(int i) => {
  'id': 'c.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'cloze',
  'explanation': 'Cloze explained $i',
  'text': 'The {{1}} is big.',
  'gaps': {
    '1': ['cat'],
  },
};

List<LoadedPack> _packs(List<Map<String, dynamic>> items) => [
  LoadedPack(
    ContentPack({
      'id': 'p',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': 3,
      'topic': 't',
      'title': 'p',
      'items': items,
    }),
  ),
];

QuizSession _session(List<Map<String, dynamic>> items, {int take = 1}) {
  final packs = _packs(items);
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', 3).take(take).toList(),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Widget _wrap(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 900),
      textScaler: TextScaler.linear(scale),
    ),
    child: child,
  ),
);

void main() {
  testWidgets(
    'B-17: letter tiles are small squares, not full-width bars; typing a letter picks it',
    (t) async {
      t.view.physicalSize = const Size(1280, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = _session([_word(1, 'dog'), _word(2, 'cat'), _word(3, 'pig')]);
      await t.pumpWidget(
        MaterialApp(
          home: WordBuilderScreen(
            session: s,
            mode: MiniGameMode.game,
            onExit: () {},
            level: WordLevel.older,
            random: Random(1),
          ),
        ),
      );
      await t.pump();
      final round = WordRound.fromItem(
        s.items.first.item,
        WordLevel.older,
        Random(1),
      );
      final tiles = round.current!.tiles;
      for (var i = 0; i < tiles.length; i++) {
        final size = t.getSize(find.byKey(WordBuilderIds.wordBuilderTile(i)));
        expect(size.width, lessThan(120), reason: 'tile $i');
      }
      expect(find.text('Check (1)'), findsOneWidget);
      expect(find.text('Undo (Backspace / 2)'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.keyD);
      await t.sendKeyEvent(LogicalKeyboardKey.keyO);
      await t.pump();
      expect(find.text('do'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pump();
      expect(find.text('d'), findsWidgets);
      expect(find.text('do'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
}
