import 'package:flutter/material.dart';
import 'package:flutter_game_template/ui/layout/responsive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('window classes change at 600 and 1024', () {
    expect(WindowClass.of(390), WindowClass.compact);
    expect(WindowClass.of(599.9), WindowClass.compact);
    expect(WindowClass.of(600), WindowClass.medium);
    expect(WindowClass.of(1023), WindowClass.medium);
    expect(WindowClass.of(1024), WindowClass.expanded);
    expect(WindowClass.of(2560), WindowClass.expanded);
  });

  test('the content gets wider with the window and a phone is unlimited', () {
    expect(contentMaxWidth(WindowClass.compact), double.infinity);
    expect(contentMaxWidth(WindowClass.medium), 720);
    expect(contentMaxWidth(WindowClass.expanded), 1120);
  });

  test('grid columns: 2 on a phone, more on a wide window, at most 6', () {
    expect(gridColumns(390), 2);
    expect(gridColumns(800), 5);
    expect(gridColumns(3000), 6);
  });

  Future<void> pump(WidgetTester t, double width, Widget child) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('ResponsiveBody limits the width on a desktop window only', (
    t,
  ) async {
    const key = Key('body');
    await pump(t, 1600, const ResponsiveBody(child: SizedBox.expand(key: key)));
    expect(t.getSize(find.byKey(key)).width, 1120);
    await pump(t, 800, const ResponsiveBody(child: SizedBox.expand(key: key)));
    expect(t.getSize(find.byKey(key)).width, 720);
    await pump(t, 400, const ResponsiveBody(child: SizedBox.expand(key: key)));
    expect(t.getSize(find.byKey(key)).width, 400);
  });

  testWidgets(
    'TwoPane stacks on a phone and sits side by side on a wider window',
    (t) async {
      const main = SizedBox(key: Key('main'), height: 100);
      const side = SizedBox(key: Key('side'), height: 100);
      await pump(t, 400, const TwoPane(main: main, side: side));
      expect(
        t.getTopLeft(find.byKey(const Key('side'))).dy,
        greaterThan(t.getTopLeft(find.byKey(const Key('main'))).dy),
      );
      await pump(t, 1200, const TwoPane(main: main, side: side));
      expect(
        t.getTopLeft(find.byKey(const Key('side'))).dy,
        t.getTopLeft(find.byKey(const Key('main'))).dy,
      );
      expect(t.getSize(find.byKey(const Key('side'))).width, 320);
    },
  );
}
