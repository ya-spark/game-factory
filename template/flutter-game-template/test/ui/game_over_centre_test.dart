import 'package:flutter_game_template/ui/game_over_panel.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared game over panel with every slot filled (same file in all games and the template).
Widget _app({double textScale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: GameOverPanel(
      panelKey: TestIds.gameOverPanel,
      viewKey: TestIds.gameOverView,
      title: 'Game over',
      shareButton: const GameOverButton(
        kind: GameOverButtonKind.ghost,
        icon: Icons.share,
        semanticLabel: 'Share',
        onPressed: null,
      ),
      details: const [Text('Score 120'), Text('Best 300')],
      buttons: [
        GameOverButton(
          key: TestIds.gameOverRetry,
          label: 'Play again',
          onPressed: () {},
        ),
        GameOverButton(
          key: TestIds.gameOverHome,
          kind: GameOverButtonKind.ghost,
          label: 'Home',
          onPressed: () {},
        ),
      ],
      extraButton: GameOverButton(label: 'Extra action', onPressed: () {}),
      leadButton: GameOverButton(
        key: TestIds.gameOverRevive,
        kind: GameOverButtonKind.primary,
        label: 'Continue \u00b7 3 left',
        onPressed: () {},
      ),
    ),
  ),
);

void main() {
  for (final size in const [Size(360, 640), Size(400, 800)]) {
    testWidgets('game over panel is vertically centred at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 1100)); // ease-in finished
      final card = tester.getRect(find.byKey(TestIds.gameOverPanel));
      expect(card.center.dy, closeTo(size.height / 2, 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('game over panel fits at 360 x 592 with text scale 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 592);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(textScale: 1.3));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byKey(TestIds.gameOverPanel));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(card.bottom, lessThanOrEqualTo(592));
  });

  testWidgets('the extra row sits between Play again / Home and Continue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 1100));
    final again = tester.getRect(find.byKey(TestIds.gameOverRetry));
    final home = tester.getRect(find.byKey(TestIds.gameOverHome));
    final extra = tester.getRect(find.text('Extra action'));
    final cont = tester.getRect(find.byKey(TestIds.gameOverRevive));
    expect((again.center.dy - home.center.dy).abs(), lessThan(2));
    expect(extra.top, greaterThan(again.bottom));
    expect(cont.top, greaterThan(extra.bottom));
  });
}
