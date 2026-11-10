import 'dart:convert';
import 'dart:io';

import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/content/connectivity_probe.dart';
import 'package:flutter_game_template/core/content/learning_service.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/content_cli.dart';
import 'delivery_test.dart' as d;

const _catalogueJson = '''
{
  "currency": "AUD", "region": "AU",
  "tiers": {"t1": "0.99", "t2": "1.99", "t3": "2.99"},
  "bundles": [
    {"product_id": "bundle_3_all", "year": 3, "tier": "t3",
     "title": "Year 3 bundle", "description": "Every Year 3 pack.", "status": "live"}
  ],
  "retired_ids": ["pack_maths_3_old"]
}''';

Map<String, dynamic> manifest(
  String id,
  String productId, {
  String? tier = 't2',
  String? status = 'live',
  int year = 3,
}) => {
  'id': id,
  'subject': 'maths',
  'year': year,
  'title': 'Pack $id',
  'product_id': productId,
  'tier': ?tier,
  'status': ?status,
  'preview': {'description': 'A preview of $id.'},
};

class RestoreProbe extends FakePurchaseService {
  RestoreProbe(this.calls) : super(const ProductCatalog([]));
  final List<String> calls;
  @override
  Future<void> registerExtraProducts(Set<String> ids) async =>
      calls.add('register:${(ids.toList()..sort()).join(',')}');
  @override
  Future<void> restore() async => calls.add('restore');
}

void main() {
  group('product-id rule', () {
    test('accepts pack_<subject>_<year>_<slug>', () {
      for (final id in [
        'pack_maths_3_times_tables',
        'pack_english_0_letters',
        'pack_maths_12_calculus2',
      ]) {
        expect(packProductIdProblem(id), isNull, reason: id);
      }
      expect(
        packProductIdProblem(
          'pack_maths_3_fractions',
          subject: 'maths',
          year: 3,
        ),
        isNull,
      );
    });

    test('rejects everything else', () {
      for (final id in [
        'Pack_maths_3_x', // upper case
        'pack_maths_3', // no slug
        'pack_maths_13_x', // year out of range
        'pack_maths_03_x', // leading zero
        'pack_maths_3_Times', // upper case slug
        'pack_maths_3_a-b', // dash
        'pack_maths_3_a__b', // empty slug part
        'pack_3_x', // no subject
        'bundle_3_all', // wrong prefix
        'pack_maths_3_${'x' * 40}', // too long
        '',
      ]) {
        expect(packProductIdProblem(id), isNotNull, reason: id);
      }
    });

    test('must match the pack subject and year', () {
      expect(
        packProductIdProblem('pack_maths_3_x', subject: 'english'),
        contains('subject'),
      );
      expect(packProductIdProblem('pack_maths_3_x', year: 4), contains('year'));
    });

    test('bundle ids are bundle_<year>_<slug>', () {
      expect(bundleProductIdProblem('bundle_3_all', year: 3), isNull);
      expect(bundleProductIdProblem('bundle_3_all', year: 4), isNotNull);
      expect(bundleProductIdProblem('bundle_all'), isNotNull);
      expect(bundleProductIdProblem('pack_maths_3_x'), isNotNull);
    });
  });

  group('price tiers', () {
    test('lookup', () {
      final c = Catalogue.parse(_catalogueJson);
      expect(c.priceOf('t1'), '0.99');
      expect(c.priceOf('t3'), '2.99');
      expect(c.priceOf('t9'), isNull);
      expect(c.currency, 'AUD');
    });

    test('a bad catalogue is rejected with every problem named', () {
      expect(
        () => Catalogue.parse(
          '{"currency":"aud","region":"AU","tiers":{"t1":1.99},"bundles":[]}',
        ),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('currency'))
              .having((e) => e.message, 'message', contains('t1')),
        ),
      );
      expect(
        () => Catalogue.parse(
          '{"currency":"AUD","region":"AU","tiers":{"t1":"1.99"},'
          '"bundles":[{"product_id":"bundle_3_a","year":3,"tier":"t7","title":"x"}]}',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('the shipped catalogue parses', () {
      final c = Catalogue.parse(
        File('content/catalogue.json').readAsStringSync(),
      );
      expect(c.tiers, hasLength(6));
    });
  });

  group('products output', () {
    final cat = Catalogue.parse(_catalogueJson);

    test('packs and a year bundle become products', () {
      final plan = buildProducts(cat, [
        manifest('a', 'pack_maths_3_add'),
        manifest('b', 'pack_maths_3_mul', tier: 't1', status: 'draft'),
        manifest('c', 'pack_maths_4_div', year: 4),
        {'id': 'built_in', 'product_id': null, 'subject': 'maths', 'year': 3},
      ]);
      expect(plan.problems, isEmpty);
      expect(plan.products.map((p) => p.productId), [
        'bundle_3_all',
        'pack_maths_3_add',
        'pack_maths_3_mul',
        'pack_maths_4_div',
      ]);
      final bundle = plan.products.first;
      expect(bundle.kind, 'bundle');
      expect(bundle.packs, ['a', 'b']); // year 3 only, no built-in
      expect(bundle.price, '2.99');

      final j = jsonDecode(plan.toJsonText()) as Map;
      expect(j['currency'], 'AUD');
      final mul = (j['products'] as List)[2] as Map;
      expect(mul['product_id'], 'pack_maths_3_mul');
      expect(mul['price'], '0.99');
      expect(mul['status'], 'draft');
      expect(mul['description'], 'A preview of b.');
    });

    test('the Play CSV has the sample columns, two rows per product', () {
      final plan = buildProducts(cat, [manifest('a', 'pack_maths_3_add')]);
      final lines = plan.toPlayCsv().trimRight().split('\n');
      final sample = File(
        '../../docs/play-import/one_time_products_sample.csv',
      );
      if (sample.existsSync()) {
        expect(lines.first, sample.readAsLinesSync().first);
      }
      // header + (pack + bundle) x 2 rows
      expect(lines, hasLength(1 + 2 * 2));
      expect(lines[3], startsWith('pack_maths_3_add,en-AU,Pack a,'));
      expect(lines[4], contains('buy,active,buy,true,false'));
      expect(lines[4], contains('AU,AUD 1.99,available'));
      expect(lines.every((l) => l.split(',').length >= 39), isTrue);
    });

    test('problems: id rule, tier, duplicates, retired ids, mismatches', () {
      final plan = buildProducts(cat, [
        manifest('a', 'pack_maths_3_Bad'),
        manifest('b', 'pack_maths_3_ok', tier: null),
        manifest('c', 'pack_maths_3_nine', tier: 't9'),
        manifest('d', 'pack_maths_3_dup'),
        manifest('e', 'pack_maths_3_dup'),
        manifest('f', 'pack_maths_3_old'.replaceFirst('old', 'old')),
        manifest('g', 'pack_maths_5_wrongyear'),
        manifest('h', 'pack_maths_3_stat', status: 'maybe'),
      ]);
      final text = plan.problems.join('\n');
      expect(plan.ok, isFalse);
      expect(text, contains('pack a'));
      expect(text, contains('pack b: needs a "tier"'));
      expect(text, contains('"t9"'));
      expect(text, contains('used by both pack d and pack e'));
      expect(text, contains('pack g'));
      expect(text, contains('year 5'));
      expect(text, contains('pack h: "status"'));
    });

    test('a retired id can never be reused', () {
      final plan = buildProducts(cat, [manifest('a', 'pack_maths_3_old')]);
      expect(plan.problems.join(), contains('retired'));
    });

    test('a bundle with no packs is a problem', () {
      final plan = buildProducts(cat, [
        manifest('c', 'pack_maths_4_x', year: 4),
      ]);
      expect(plan.problems.join(), contains('bundle_3_all'));
    });
  });

  group('index status and bundles', () {
    test('the validator accepts draft and live, rejects others', () {
      final topics = Topics.parse(
        File('content/topics.yaml').readAsStringSync(),
      );
      ValidationResult check(String? status) {
        final p = d.pack('p1', 20, productId: 'pack_maths_3_x');
        p['status'] = status;
        p['tier'] = 't1';
        p['preview'] = {
          'description': 'x',
          'outline': [
            {'topic': 'times_tables', 'count': 20},
          ],
          'item_ids': <String>[],
        };
        return validatePacks([MapEntry('p1', p)], topics: topics);
      }

      expect(
        check('draft').errors.where((e) => '$e'.contains('status')),
        isEmpty,
      );
      expect(
        check('live').errors.where((e) => '$e'.contains('status')),
        isEmpty,
      );
      expect(
        check('soon').errors.where((e) => '$e'.contains('status')),
        isNotEmpty,
      );
    });

    test('buildIndex writes status; an extra pack without one is draft', () {
      final p = d.pack('p1', 3, productId: 'pack_maths_3_x')..remove('status');
      final idx = buildIndex(
        app: 'a',
        version: 1,
        packFiles: {'packs/p1.json': d.b(jsonEncode(p))},
        readAsset: (_) => null,
        bundles: [
          {
            'product_id': 'bundle_3_all',
            'title': 'B',
            'year': 3,
            'status': 'live',
            'packs': ['p1'],
          },
        ],
      );
      expect((idx['packs'] as List).single['status'], 'draft');
      final parsed = ContentIndex.parse(encodeIndex(idx));
      expect(parsed.packs.single.isLive, isFalse);
      expect(parsed.bundles.single.packs, ['p1']);
      expect(parsed.bundles.single.isLive, isTrue);
    });
  });

  group('app behaviour', () {
    Future<ContentRepository> repoFor(
      List<Map<String, dynamic>> packs,
      List<Map<String, dynamic>> bundles,
      Set<String> owned,
    ) async {
      final files = {
        for (final p in packs) 'packs/${p['id']}.json': d.b(jsonEncode(p)),
      };
      final idx = encodeIndex(
        buildIndex(
          app: d.app,
          version: 1,
          packFiles: files,
          readAsset: (_) => null,
          bundles: bundles,
        ),
      );
      return ContentRepository(
        builtIn: BuiltInContentSource(
          (path) async => path.endsWith('index.json')
              ? idx
              : files[path.replaceFirst('assets/content/', '')],
          appId: d.app,
        ),
        isOwned: owned.contains,
      );
    }

    final bundle = {
      'product_id': 'bundle_3_all',
      'title': 'Year 3',
      'year': 3,
      'status': 'live',
      'packs': ['p1', 'p2'],
    };

    test('a draft pack is hidden and never listed for sale', () async {
      final repo = await repoFor(
        [
          d.pack('p1', 3, productId: 'pack_maths_3_a', status: 'draft'),
          d.pack('p2', 3, productId: 'pack_maths_3_b'),
        ],
        [],
        {},
      );
      expect(await repo.productIds(), {'pack_maths_3_b'});
      final all = await repo.catalog();
      expect(all, hasLength(2)); // the repository knows both
      expect(
        (await repo.download(
          all.first,
          PackPart.full,
          connection: ConnectionKind.wifi,
        )).status,
        DownloadStatus.failed,
      );
    });

    test('a live pack is buyable: its product id goes to Play', () async {
      final repo = await repoFor(
        [d.pack('p2', 3, productId: 'pack_maths_3_b')],
        [bundle],
        {},
      );
      expect(await repo.productIds(), {'pack_maths_3_b', 'bundle_3_all'});
    });

    test('a draft bundle is not offered', () async {
      final repo = await repoFor(
        [d.pack('p2', 3, productId: 'pack_maths_3_b')],
        [
          {...bundle, 'status': 'draft'},
        ],
        {},
      );
      expect(await repo.productIds(), {'pack_maths_3_b'});
    });

    test('owning a bundle owns each pack in it, and only those', () async {
      final owned = <String>{};
      final repo = await repoFor(
        [
          d.pack('p1', 3, productId: 'pack_maths_3_a'),
          d.pack('p2', 3, productId: 'pack_maths_3_b'),
          d.pack('p3', 3, productId: 'pack_maths_3_c'),
        ],
        [bundle],
        owned,
      );
      final cat = await repo.catalog();
      bool owns(String id) =>
          repo.owns(cat.firstWhere((c) => c.id == id).entry);
      expect([owns('p1'), owns('p2'), owns('p3')], [false, false, false]);
      owned.add('bundle_3_all');
      expect([owns('p1'), owns('p2'), owns('p3')], [true, true, false]);
      owned
        ..remove('bundle_3_all')
        ..add('pack_maths_3_c');
      expect([owns('p1'), owns('p2'), owns('p3')], [false, false, true]);
    });

    test('a bundle purchase is stored on the device like a pack', () {
      expect(isExtraProductId('bundle_3_all'), isTrue);
      expect(isExtraProductId('pack_maths_3_a'), isTrue);
      expect(isExtraProductId('unlock_full'), isFalse);
    });

    test('restore asks Play about the index products, then restores', () async {
      final calls = <String>[];
      final repo = await repoFor(
        [
          d.pack('p1', 3, productId: 'pack_maths_3_a', status: 'draft'),
          d.pack('p2', 3, productId: 'pack_maths_3_b'),
        ],
        [bundle],
        {},
      );
      final store = ProfileStore(
        saves: MemorySaveService(),
        retention: const RetentionConfig(),
        clock: DateTime.now,
      );
      await store.init();
      final svc = LearningService(
        config: const ContentConfig(),
        profile: store,
        repository: repo,
        connectivity: FakeConnectivityProbe(),
        purchases: RestoreProbe(calls),
      );
      await svc.restorePurchases();
      expect(calls, ['register:bundle_3_all,pack_maths_3_b', 'restore']);
    });
  });

  group('content_cli products and publish', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('catalogue_cli'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<(int, String, String)> run(
      List<String> args, {
      Map<String, String> env = const {},
    }) async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runCli(args, env: env, out: out, err: err);
      return (code, '$out', '$err');
    }

    Map<String, dynamic> real(String id, String productId, {String? tier}) {
      final p = d.pack(id, 20, productId: productId);
      p['licence'] = 'original';
      p.remove('status'); // authors leave it out until the product exists
      p['tier'] = tier ?? 't2';
      p['preview'] = {
        'description': 'Preview of $id.',
        'outline': [
          {'topic': 'times_tables', 'count': 20},
        ],
        'item_ids': <String>[],
      };
      return p;
    }

    test('products writes JSON and CSV', () async {
      Directory('${tmp.path}/packs').createSync();
      File('${tmp.path}/cat.json').writeAsStringSync(_catalogueJson);
      File('${tmp.path}/packs/a.json')
          .writeAsStringSync(jsonEncode(real('a', 'pack_maths_3_add')));
      final r = await run([
        'products',
        '--packs',
        '${tmp.path}/packs',
        '--catalogue',
        '${tmp.path}/cat.json',
        '--json-out',
        '${tmp.path}/products.json',
        '--csv-out',
        '${tmp.path}/products.csv',
      ]);
      expect(r.$1, 0, reason: r.$3);
      final j = jsonDecode(
        File('${tmp.path}/products.json').readAsStringSync(),
      );
      expect((j['products'] as List).map((p) => p['product_id']), [
        'bundle_3_all',
        'pack_maths_3_add',
      ]);
      expect(
        File('${tmp.path}/products.csv').readAsStringSync(),
        contains('AUD 1.99'),
      );
    });

    test('products refuses a bad id and writes nothing', () async {
      Directory('${tmp.path}/packs').createSync();
      File('${tmp.path}/cat.json').writeAsStringSync(_catalogueJson);
      File('${tmp.path}/packs/a.json')
          .writeAsStringSync(jsonEncode(real('a', 'pack_Bad')));
      final r = await run([
        'products',
        '--packs',
        '${tmp.path}/packs',
        '--catalogue',
        '${tmp.path}/cat.json',
        '--json-out',
        '${tmp.path}/products.json',
      ]);
      expect(r.$1, 1);
      expect(r.$3, contains('not a pack product id'));
      expect(File('${tmp.path}/products.json').existsSync(), isFalse);
    });

    test(
      'publish builds the index with status and bundles; dry run only',
      () async {
        Directory('${tmp.path}/packs').createSync();
        File('${tmp.path}/cat.json').writeAsStringSync(_catalogueJson);
        File('${tmp.path}/packs/a.json')
            .writeAsStringSync(jsonEncode(real('a', 'pack_maths_3_add')));
        final args = [
          'publish',
          '--app',
          'craft_lowteen',
          '--packs',
          '${tmp.path}/packs',
          '--out',
          '${tmp.path}/site',
          '--catalogue',
          '${tmp.path}/cat.json',
        ];
        var r = await run(args);
        expect(r.$1, 0, reason: '${r.$2}${r.$3}');
        expect(r.$2, contains('NOT SIGNED'));
        expect(r.$2, contains('DRY RUN'));
        expect(r.$2, contains('packs/a.json'));
        expect(File('${tmp.path}/site/index.sig').existsSync(), isFalse);
        final idx = jsonDecode(
          File('${tmp.path}/site/index.json').readAsStringSync(),
        );
        expect(idx['packs'][0]['status'], 'draft'); // no status in the manifest
        expect(idx['bundles'][0]['packs'], ['a']);

        final env = {
          'CONTENT_SIGNING_KEY_FILE': 'test/fixtures/test_only_signing_key.txt',
        };
        r = await run(args, env: env);
        expect(r.$1, 0, reason: r.$3);
        expect(File('${tmp.path}/site/index.sig').existsSync(), isTrue);
        expect(r.$2, contains('index.sig'));

        r = await run([...args, '--sign', 'no'], env: env);
        expect(r.$2, contains('NOT SIGNED'));
        r = await run([...args, '--sign', 'yes']);
        expect(r.$1, 1);
      },
    );

    test('publish stops on a product problem', () async {
      Directory('${tmp.path}/packs').createSync();
      File('${tmp.path}/cat.json').writeAsStringSync(_catalogueJson);
      File('${tmp.path}/packs/a.json').writeAsStringSync(
        jsonEncode(real('a', 'pack_maths_3_add', tier: 't9')),
      );
      final r = await run([
        'publish',
        '--app',
        'x',
        '--packs',
        '${tmp.path}/packs',
        '--out',
        '${tmp.path}/site',
        '--catalogue',
        '${tmp.path}/cat.json',
      ]);
      expect(r.$1, 1);
      expect(r.$3, contains('product problems'));
      expect(File('${tmp.path}/site/index.json').existsSync(), isFalse);
    });
  });
}
