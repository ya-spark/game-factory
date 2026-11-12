import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../engine/engine.dart';

/// The content cache in the app documents directory. (The web build uses `content_io_web.dart`.)
Future<DirectoryContentStore> openContentCache() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/content');
  await dir.create(recursive: true);
  return DirectoryContentStore(dir);
}

/// Cache in a directory of the app documents folder. A write puts every file under a temporary
/// name first and renames them only when all are complete, so a broken download leaves nothing.
class DirectoryContentStore implements ContentStore {
  DirectoryContentStore(this.root);
  final Directory root;

  File _file(String name) => File('${root.path}/$name');

  @override
  Future<Uint8List?> read(String name) async {
    final f = _file(name);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> writeAll(Map<String, Uint8List> files) async {
    final temps = <File, File>{};
    try {
      for (final e in files.entries) {
        final target = _file(e.key);
        await target.parent.create(recursive: true);
        final tmp = File('${target.path}.part');
        await tmp.writeAsBytes(e.value, flush: true);
        temps[tmp] = target;
      }
    } on Object {
      for (final t in temps.keys) {
        if (await t.exists()) await t.delete();
      }
      rethrow;
    }
    for (final e in temps.entries) {
      await e.key.rename(e.value.path);
    }
  }
}

/// HTTPS GET with `dart:io`. No cookies, no body, no custom headers: nothing about the child is
/// sent. Anything but status 200 throws.
class HttpContentFetcher implements ContentFetcher {
  HttpContentFetcher({this.timeout = const Duration(seconds: 20)});
  final Duration timeout;

  @override
  Future<Uint8List> get(Uri url) async {
    if (url.scheme != 'https') {
      throw ArgumentError('only https is allowed: $url');
    }
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(url);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) {
        throw HttpException('status ${res.statusCode}', uri: url);
      }
      final b = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(timeout)) {
        b.add(chunk);
      }
      return b.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}
