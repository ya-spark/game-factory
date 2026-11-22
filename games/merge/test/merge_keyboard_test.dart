import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_merge/merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keyboard play (docs/SPEC.md, Keyboard): Enter starts, arrows slide, Esc goes back to the menu.
void main() {
  testWidgets(
    'Enter starts, an arrow slides the board, Esc returns to the menu',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(
        MaterialApp(
          home: GameHostScope(
            host: const NoGameHost(),
            child: MergeScreen(random: Random(3)),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(MindIds.calmControl('merge', 'board')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(find.byKey(MindIds.calmControl('merge', 'board')), findsOneWidget);
      String cells() => [
        for (var i = 0; i < 16; i++)
          t
                  .widget<Semantics>(
                    find
                        .ancestor(
                          of: find.byKey(MergeIds.mergeCell(i)),
                          matching: find.byType(Semantics),
                        )
                        .first,
                  )
                  .properties
                  .label ??
              '',
      ].join('|');
      final before = cells();
      for (final k in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await t.sendKeyEvent(k);
        await t.pump();
      }
      expect(cells(), isNot(before));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byKey(MindIds.calmControl('merge', 'board')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
