/// Content authoring tool. Run from the project root:
///
///   dart run tool/content_cli.dart COMMAND [options]
///
/// Commands: from-csv, validate, pool, build-index, sign, public-key.
/// See docs/CONTENT_FORMAT.md.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_game_template/engine/engine.dart';

const String _usage = '''
Usage: dart run tool/content_cli.dart <command> [options]

  from-csv <pack.csv> --out <dir>      CSV to <dir>/<id>.json (+ <id>.ids), then validate
  validate <file|dir>...               check packs; exit 1 on any error (warnings do not fail)
  pool <file|dir>...                   count items per type, subject, year and topic
  build-index --app <id> --packs <dir> --out <dir> [--version N]
                                       write <dir>/index.json with sha256 and size of every file
  sign --index <index.json> [--out <file>]
                                       sign with the key file named in CONTENT_SIGNING_KEY_FILE
  public-key                           print the public key for CONTENT_SIGNING_KEY_FILE

Common options: --topics <file> (default content/topics.yaml), --root <dir> (project root
for asset paths and assets/LICENSES.md, default .)
''';

Future<void> main(List<String> args) async {
  exit(await runCli(args, env: Platform.environment, out: stdout, err: stderr));
}

class _Opts {
  _Opts(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a.startsWith('--')) {
        if (i + 1 >= args.length) throw FormatException('$a needs a value');
        named[a.substring(2)] = args[++i];
      } else {
        positional.add(a);
      }
    }
  }
  final Map<String, String> named = {};
  final List<String> positional = [];
}

/// Runs the tool; returns the exit code. Testable: no global state.
Future<int> runCli(
  List<String> args, {
  required Map<String, String> env,
  required StringSink out,
  required StringSink err,
}) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    out.write(_usage);
    return args.isEmpty ? 64 : 0;
  }
  final _Opts o;
  try {
    o = _Opts(args.sublist(1));
  } on FormatException catch (e) {
    err.writeln(e.message);
    return 64;
  }
  final root = o.named['root'] ?? '.';
  final topicsPath = o.named['topics'] ?? '$root/content/topics.yaml';
  try {
    switch (args.first) {
      case 'from-csv':
        return await _fromCsv(o, root, topicsPath, out, err);
      case 'validate':
        return _validate(o, root, topicsPath, out, err);
      case 'pool':
        return _pool(o, root, topicsPath, out, err);
      case 'build-index':
        return _buildIndex(o, root, topicsPath, out, err);
      case 'sign':
        return await _sign(o, env, out, err);
      case 'public-key':
        out.writeln(await publicKeyOf(_key(env)));
        return 0;
      default:
        err.writeln('unknown command "${args.first}"\n$_usage');
        return 64;
    }
  } on FormatException catch (e) {
    err.writeln('error: ${e.message}');
    return 1;
  } on FileSystemException catch (e) {
    err.writeln('error: ${e.message} ${e.path ?? ''}');
    return 1;
  } on StateError catch (e) {
    err.writeln('error: ${e.message}');
    return 1;
  }
}

Topics _topics(String path) {
  final f = File(path);
  if (!f.existsSync()) throw FormatException('topics file not found: $path');
  return Topics.parse(f.readAsStringSync());
}

AssetChecker _assets(String root) {
  final lic = File('$root/assets/LICENSES.md');
  return AssetChecker(
    exists: (p) => File('$root/$p').existsSync(),
    licensesText: lic.existsSync() ? lic.readAsStringSync() : '',
  );
}

/// Pack JSON files under [paths] (files, or directories searched recursively).
/// Ignores `*.ids` and `index.json`.
List<File> _packFiles(List<String> paths) {
  final files = <File>[];
  for (final p in paths) {
    if (FileSystemEntity.isDirectorySync(p)) {
      for (final e in Directory(p).listSync(recursive: true)) {
        if (e is File) files.add(e);
      }
    } else {
      files.add(File(p));
    }
  }
  return [
    for (final f in files)
      if (f.path.endsWith('.json') &&
          !f.path.endsWith('index.json') &&
          !f.path.endsWith('.ids.json'))
        f,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

List<MapEntry<String, Object?>> _decode(List<File> files, StringSink err) {
  final out = <MapEntry<String, Object?>>[];
  for (final f in files) {
    try {
      out.add(MapEntry(f.path, jsonDecode(f.readAsStringSync())));
    } on FormatException catch (e) {
      throw FormatException('${f.path}: not valid JSON (${e.message})');
    }
  }
  return out;
}

void _print(ValidationResult r, StringSink out) {
  for (final i in r.issues) {
    out.writeln(i);
  }
}

int _validate(
  _Opts o,
  String root,
  String topicsPath,
  StringSink out,
  StringSink err,
) {
  if (o.positional.isEmpty) {
    err.writeln('validate needs a file or directory');
    return 64;
  }
  final files = _packFiles(o.positional);
  if (files.isEmpty) {
    err.writeln('no pack files found');
    return 1;
  }
  final r = validatePacks(
    _decode(files, err),
    topics: _topics(topicsPath),
    assets: _assets(root),
  );
  _print(r, out);
  out.writeln(
    '${files.length} pack(s): ${r.errors.length} error(s), ${r.warnings.length} warning(s)',
  );
  return r.ok ? 0 : 1;
}

int _pool(
  _Opts o,
  String root,
  String topicsPath,
  StringSink out,
  StringSink err,
) {
  final files = _packFiles(o.positional.isEmpty ? ['.'] : o.positional);
  final decoded = _decode(files, err);
  final r = validatePacks(decoded, topics: _topics(topicsPath));
  if (!r.ok) {
    _print(ValidationResult(r.errors), err);
    err.writeln('fix the errors first (run validate)');
    return 1;
  }
  out.write(
    PoolReport.of([
      for (final d in decoded) ContentPack(d.value as Map<String, dynamic>),
    ]).format(),
  );
  return 0;
}

Future<int> _fromCsv(
  _Opts o,
  String root,
  String topicsPath,
  StringSink out,
  StringSink err,
) async {
  if (o.positional.length != 1 || o.named['out'] == null) {
    err.writeln('from-csv needs one CSV file and --out <dir>');
    return 64;
  }
  final csv = File(o.positional.single).readAsStringSync();
  // The id of the pack comes from the CSV; read the previous ids file first.
  final probe = convertCsv(csv);
  final outDir = Directory(o.named['out']!)..createSync(recursive: true);
  final packId = probe.pack['id'] as String? ?? '';
  final idsFile = File('${outDir.path}/$packId.ids');
  final previous = packId.isNotEmpty && idsFile.existsSync()
      ? idsFile.readAsStringSync()
      : null;
  final conv = convertCsv(csv, previousIds: previous);
  for (final p in conv.problems) {
    err.writeln('ERROR [csv] $p');
  }
  if (!conv.ok) return 1;

  final r = validatePack(
    conv.pack,
    topics: _topics(topicsPath),
    assets: _assets(root),
    fileLabel: o.positional.single,
  );
  _print(r, out);
  if (!r.ok) {
    err.writeln('${r.errors.length} error(s): nothing written');
    return 1;
  }
  const enc = JsonEncoder.withIndent('  ');
  File('${outDir.path}/$packId.json')
      .writeAsStringSync('${enc.convert(conv.pack)}\n');
  idsFile.writeAsStringSync('${enc.convert(conv.idsJson)}\n');
  out.writeln(
    'wrote ${outDir.path}/$packId.json (${(conv.pack['items'] as List).length} items) '
    'and $packId.ids; ${r.warnings.length} warning(s)',
  );
  return 0;
}

int _buildIndex(
  _Opts o,
  String root,
  String topicsPath,
  StringSink out,
  StringSink err,
) {
  final app = o.named['app'];
  final packsDir = o.named['packs'];
  final outDir = o.named['out'];
  if (app == null || packsDir == null || outDir == null) {
    err.writeln('build-index needs --app, --packs and --out');
    return 64;
  }
  final files = _packFiles([packsDir]);
  if (files.isEmpty) {
    err.writeln('no pack files in $packsDir');
    return 1;
  }
  final decoded = _decode(files, err);
  final r = validatePacks(
    decoded,
    topics: _topics(topicsPath),
    assets: _assets(root),
  );
  if (!r.ok) {
    _print(ValidationResult(r.errors), err);
    err.writeln('index not built: fix the errors first');
    return 1;
  }
  final packFiles = <String, Uint8List>{
    for (final f in files)
      'packs/${f.uri.pathSegments.last}': f.readAsBytesSync(),
  };
  final index = buildIndex(
    app: app,
    version: int.parse(o.named['version'] ?? '1'),
    packFiles: packFiles,
    readAsset: (p) {
      final f = File('$root/$p');
      return f.existsSync() ? f.readAsBytesSync() : null;
    },
  );
  Directory(outDir).createSync(recursive: true);
  File('$outDir/index.json').writeAsBytesSync(encodeIndex(index));
  out.writeln('wrote $outDir/index.json (${files.length} pack(s))');
  return 0;
}

List<int> _key(Map<String, String> env) {
  final path = env['CONTENT_SIGNING_KEY_FILE'];
  if (path == null || path.isEmpty) {
    throw const FormatException('CONTENT_SIGNING_KEY_FILE is not set');
  }
  return parseSigningKey(File(path).readAsStringSync());
}

Future<int> _sign(
  _Opts o,
  Map<String, String> env,
  StringSink out,
  StringSink err,
) async {
  final indexPath = o.named['index'];
  if (indexPath == null) {
    err.writeln('sign needs --index <index.json>');
    return 64;
  }
  final sig = await signIndex(File(indexPath).readAsBytesSync(), _key(env));
  final target = o.named['out'] ?? '$indexPath.sig';
  File(target).writeAsStringSync('$sig\n');
  out.writeln('wrote $target');
  return 0;
}
