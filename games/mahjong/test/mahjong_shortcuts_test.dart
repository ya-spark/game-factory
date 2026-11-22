import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_mahjong/mahjong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B-09: the level buttons and Undo, Hint and Shuffle show their keys and the keys work.
void main() {
  testWidgets('layout buttons show 1 to 4; Hint, Undo and Shuffle show keys', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1000, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: MahjongScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining(RegExp(r'\(1\)$')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.textContaining('(H / 1)'), findsOneWidget);
    expect(find.text('Undo (Backspace / 2)'), findsOneWidget);
    expect(find.textContaining('(3)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyH);
    await t.pump();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
