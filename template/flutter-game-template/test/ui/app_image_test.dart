import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game_template/ui/app_image.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1x1 PNG.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _Bundle extends CachingAssetBundle {
  _Bundle(this.assets);
  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final k in assets.keys) k: <Object>[],
      })!;
    }
    final data = assets[key];
    if (data == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(data);
  }
}

Widget _host(
  Widget child,
  Map<String, Uint8List> assets, {
  bool reduce = false,
}) => MaterialApp(
  home: DefaultAssetBundle(
    bundle: _Bundle(assets),
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('placeholder while loading, then the image', (t) async {
    await t.pumpWidget(
      _host(const AppImage.asset('a.png', width: 40, height: 40), {
        'a.png': _png,
      }),
    );
    expect(find.byKey(TestIds.appImage), findsOneWidget);
    expect(find.byKey(TestIds.appImagePlaceholder), findsOneWidget);
    await _settle(t);
    expect(find.byKey(TestIds.appImagePlaceholder), findsNothing);
    expect(find.byKey(TestIds.appImageFallback), findsNothing);
  });

  testWidgets('a missing asset shows the drawn fallback', (t) async {
    await t.pumpWidget(
      _host(const AppImage.asset('missing.png', width: 40, height: 40), {}),
    );
    await _settle(t);
    expect(find.byKey(TestIds.appImageFallback), findsOneWidget);
    expect(find.byKey(TestIds.appImagePlaceholder), findsNothing);
  });

  testWidgets('corrupt image data shows the fallback', (t) async {
    await t.pumpWidget(
      _host(const AppImage.asset('bad.png', width: 40, height: 40), {
        'bad.png': Uint8List.fromList([1, 2, 3]),
      }),
    );
    await _settle(t);
    expect(find.byKey(TestIds.appImageFallback), findsOneWidget);
  });

  testWidgets('a missing local file shows the fallback (reduce motion)', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const AppImage.file('/nonexistent/x.png', width: 40, height: 40),
        {},
        reduce: true,
      ),
    );
    await _settle(t);
    expect(find.byKey(TestIds.appImageFallback), findsOneWidget);
  });
}
