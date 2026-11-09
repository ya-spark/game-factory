import 'dart:convert';
import 'dart:io';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/content_cli.dart';

Future<(int, String, String)> run(
  List<String> args, {
  Map<String, String> env = const {},
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(args, env: env, out: out, err: err);
  return (code, '$out', '$err');
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('content_cli_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('from-csv, validate, pool, build-index and sign end to end', () async {
    final out = '${tmp.path}/packs';
    var r = await run([
      'from-csv',
      'test/fixtures/sample_pack.csv',
      '--out',
      out,
    ]);
    expect(r.$1, 0, reason: '${r.$2}${r.$3}');
    expect(File('$out/sample_times_tables.json').existsSync(), isTrue);
    expect(File('$out/sample_times_tables.ids').existsSync(), isTrue);

    r = await run(['validate', out]);
    expect(r.$1, 0, reason: r.$2);
    expect(r.$2, contains('1 pack(s): 0 error(s), 1 warning(s)'));

    r = await run(['pool', out]);
    expect(r.$1, 0);
    expect(r.$2, contains('maths/03/times_tables'));

    r = await run([
      'build-index',
      '--app',
      'craft_lowteen',
      '--packs',
      out,
      '--out',
      tmp.path,
    ]);
    expect(r.$1, 0, reason: r.$3);
    final index = jsonDecode(File('${tmp.path}/index.json').readAsStringSync());
    expect(index['packs'][0]['file']['path'], 'packs/sample_times_tables.json');

    final env = {
      'CONTENT_SIGNING_KEY_FILE': 'test/fixtures/test_only_signing_key.txt',
    };
    r = await run(['sign', '--index', '${tmp.path}/index.json'], env: env);
    expect(r.$1, 0, reason: r.$3);
    r = await run(['public-key'], env: env);
    final pub = r.$2.trim();
    expect(
      await verifyIndex(
        File('${tmp.path}/index.json').readAsBytesSync(),
        File('${tmp.path}/index.json.sig').readAsStringSync(),
        pub,
      ),
      isTrue,
    );
  });

  test('re-running from-csv keeps ids from the ids file', () async {
    final out = '${tmp.path}/packs';
    await run(['from-csv', 'test/fixtures/sample_pack.csv', '--out', out]);
    final first = File('$out/sample_times_tables.json').readAsStringSync();
    final r = await run([
      'from-csv',
      'test/fixtures/sample_pack.csv',
      '--out',
      out,
    ]);
    expect(r.$1, 0);
    expect(File('$out/sample_times_tables.json').readAsStringSync(), first);
  });

  test('validate fails on a bad pack and names the problem', () async {
    final pack = jsonDecode(
      File('test/fixtures/sample_times_tables.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    (pack['items'] as List).first.remove('explanation');
    File('${tmp.path}/bad.json').writeAsStringSync(jsonEncode(pack));
    final r = await run(['validate', '${tmp.path}/bad.json']);
    expect(r.$1, 1);
    expect(r.$2, contains('missing_explanation'));
  });

  test('sign without a key fails, key path is never printed', () async {
    File('${tmp.path}/index.json').writeAsStringSync('{}');
    final r = await run(['sign', '--index', '${tmp.path}/index.json']);
    expect(r.$1, 1);
    expect(r.$3, contains('CONTENT_SIGNING_KEY_FILE'));
  });

  test('usage and unknown commands', () async {
    expect((await run([])).$1, 64);
    expect((await run(['nope'])).$1, 64);
    expect((await run(['--help'])).$1, 0);
  });
}
