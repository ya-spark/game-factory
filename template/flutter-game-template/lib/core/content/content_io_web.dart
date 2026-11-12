import 'dart:js_interop';
import 'dart:typed_data';

import '../../engine/engine.dart';

/// Web build: the browser has no app documents folder, so downloaded content is kept in memory
/// for the session only (built-in content ships in the bundle). A page reload downloads again.
Future<ContentStore> openContentCache() async => MemoryContentStore();

@JS('fetch')
external JSPromise<_FetchResponse> _fetch(String url, [JSObject? init]);

extension type _FetchResponse._(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

/// HTTPS GET with the browser `fetch`. No cookies, no body, no custom headers: nothing about the
/// child is sent. The server must allow the web host with CORS. Anything but status 200 throws.
class HttpContentFetcher implements ContentFetcher {
  HttpContentFetcher({this.timeout = const Duration(seconds: 20)});
  final Duration timeout;

  @override
  Future<Uint8List> get(Uri url) async {
    if (url.scheme != 'https') {
      throw ArgumentError('only https is allowed: $url');
    }
    final init =
        {'credentials': 'omit', 'cache': 'no-cache'}.jsify()! as JSObject;
    final res = await _fetch(url.toString(), init).toDart.timeout(timeout);
    if (res.status != 200) {
      throw StateError('status ${res.status}: $url');
    }
    final buf = await res.arrayBuffer().toDart.timeout(timeout);
    return buf.toDart.asUint8List();
  }
}
