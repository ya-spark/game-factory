/// Content delivery: the [ContentSource] interface, the built-in and static-server sources,
/// verification (sha256, optional Ed25519 signature, no downgrade, no rollback) and the cache.
/// Pure Dart: bytes in, bytes out. The HTTP client and the storage are injected.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'index.dart';
import 'models.dart';

/// Why a content operation failed. [code] is stable and used by tests.
class ContentException implements Exception {
  const ContentException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'ContentException[$code]: $message';
}

/// Which part of a pack: the free preview or the full pack.
enum PackPart { preview, full }

/// One file listed in an index.
class FileRef {
  const FileRef(this.path, this.sha256, this.size);
  final String path;
  final String sha256;
  final int size;

  factory FileRef.fromJson(Object? j) {
    if (j is! Map ||
        j['path'] is! String ||
        j['sha256'] is! String ||
        j['size'] is! int) {
      throw const ContentException('bad_index', 'bad file entry in the index');
    }
    final path = j['path'] as String;
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('..') ||
        path.contains('\\') ||
        path.contains(':')) {
      throw ContentException('bad_index', 'unsafe path "$path" in the index');
    }
    return FileRef(path, j['sha256'] as String, j['size'] as int);
  }

  /// Throws `hash_mismatch` unless [bytes] is exactly this file.
  void verify(List<int> bytes) {
    if (bytes.length != size || sha256Hex(bytes) != sha256) {
      throw ContentException('hash_mismatch', '$path does not match the index');
    }
  }
}

/// One pack as listed in an index.
class PackEntry {
  const PackEntry({
    required this.id,
    required this.version,
    required this.subject,
    required this.year,
    required this.topic,
    required this.title,
    required this.productId,
    required this.items,
    required this.file,
    required this.previewFile,
    required this.assets,
  });

  final String id;
  final int version;
  final String subject;
  final int year;
  final String topic;
  final String title;
  final String? productId;
  final int items;
  final FileRef file;
  final FileRef? previewFile;
  final List<FileRef> assets;

  bool get isExtra => productId != null;

  FileRef? fileFor(PackPart part) => part == PackPart.full ? file : previewFile;

  /// Download size of a part in bytes (file and assets; assets only for the full part).
  int sizeOf(PackPart part) =>
      (fileFor(part)?.size ?? 0) +
      (part == PackPart.full ? assets.fold(0, (s, a) => s + a.size) : 0);

  factory PackEntry.fromJson(Object? j) {
    if (j is! Map ||
        j['id'] is! String ||
        j['version'] is! int ||
        j['subject'] is! String ||
        j['year'] is! int ||
        j['topic'] is! String ||
        j['title'] is! String ||
        j['items'] is! int) {
      throw const ContentException('bad_index', 'bad pack entry');
    }
    return PackEntry(
      id: j['id'] as String,
      version: j['version'] as int,
      subject: j['subject'] as String,
      year: j['year'] as int,
      topic: j['topic'] as String,
      title: j['title'] as String,
      productId: j['product_id'] as String?,
      items: j['items'] as int,
      file: FileRef.fromJson(j['file']),
      previewFile: j['preview_file'] == null
          ? null
          : FileRef.fromJson(j['preview_file']),
      assets: [
        for (final a in (j['assets'] as List? ?? const [])) FileRef.fromJson(a),
      ],
    );
  }
}

/// A parsed, not yet trusted, index.
class ContentIndex {
  const ContentIndex(this.app, this.version, this.packs);
  final String app;
  final int version;
  final List<PackEntry> packs;

  static ContentIndex empty(String app) => ContentIndex(app, 0, const []);

  PackEntry? pack(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory ContentIndex.parse(List<int> bytes) {
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const ContentException('bad_index', 'index is not JSON');
    }
    if (j is! Map ||
        j['format'] != indexFormat ||
        j['app'] is! String ||
        j['version'] is! int ||
        j['packs'] is! List) {
      throw const ContentException('bad_index', 'unknown index shape');
    }
    return ContentIndex(j['app'] as String, j['version'] as int, [
      for (final p in j['packs'] as List) PackEntry.fromJson(p),
    ]);
  }
}

/// What a content source offers. Implemented by [BuiltInContentSource] and
/// [ServerContentSource].
abstract interface class ContentSource {
  Future<List<PackEntry>> listPacks();

  /// The pack part, verified against the index, or null when it is not available here.
  Future<ContentPack?> loadPack(String id, {PackPart part = PackPart.full});

  /// Asks for a newer index. Silent: never throws, failures are reported as a status.
  Future<UpdateResult> checkForUpdates();
}

enum UpdateStatus {
  /// A newer verified index is now cached.
  updated,
  upToDate,

  /// The index was refused (bad signature, unsigned, wrong app, bad shape).
  rejected,

  /// The index is older than the cached one and was ignored.
  rollbackIgnored,

  /// No network or a failed request.
  failed,
  notApplicable,
}

class UpdateResult {
  const UpdateResult(this.status, [this.code]);
  final UpdateStatus status;
  final String? code;
}

/// Reads bytes from the bundled assets. Returns null when the file is not there.
typedef AssetLoader = Future<Uint8List?> Function(String path);

/// The content bundled in the app (`assets/content/`). Always available, no network.
class BuiltInContentSource implements ContentSource {
  BuiltInContentSource(
    this._load, {
    this.root = 'assets/content/',
    required this.appId,
  });

  final AssetLoader _load;
  final String root;
  final String appId;
  ContentIndex? _index;

  Future<ContentIndex> _ensureIndex() async {
    final cached = _index;
    if (cached != null) return cached;
    final bytes = await _load('${root}index.json');
    return _index = bytes == null
        ? ContentIndex.empty(appId)
        : ContentIndex.parse(bytes);
  }

  @override
  Future<List<PackEntry>> listPacks() async => (await _ensureIndex()).packs;

  @override
  Future<ContentPack?> loadPack(
    String id, {
    PackPart part = PackPart.full,
  }) async {
    final entry = (await _ensureIndex()).pack(id);
    final ref = entry?.fileFor(part);
    if (entry == null || ref == null) return null;
    final bytes = await _load('$root${ref.path}');
    if (bytes == null) return null;
    ref.verify(bytes);
    return ContentPack(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  }

  @override
  Future<UpdateResult> checkForUpdates() async =>
      const UpdateResult(UpdateStatus.notApplicable);
}

/// HTTPS GET of one URL. Throws on any failure (no network, status other than 200).
abstract interface class ContentFetcher {
  Future<Uint8List> get(Uri url);
}

/// Cache storage. [writeAll] is all-or-nothing: nothing is visible until every file is complete.
abstract interface class ContentStore {
  Future<Uint8List?> read(String name);
  Future<void> writeAll(Map<String, Uint8List> files);
}

class MemoryContentStore implements ContentStore {
  final Map<String, Uint8List> files = {};
  @override
  Future<Uint8List?> read(String name) async => files[name];
  @override
  Future<void> writeAll(Map<String, Uint8List> f) async => files.addAll(f);
}

/// The signing key the app trusts. While [publicKey] starts with `PLACEHOLDER` signing is off
/// and an unsigned index is accepted; once a real key is set a valid signature is required.
class SigningConfig {
  const SigningConfig({required this.publicKey, required this.keyId});
  final String publicKey;
  final String keyId;

  bool get enabled => !publicKey.startsWith('PLACEHOLDER');
}

enum ConnectionKind { offline, mobile, wifi }

/// Download settings kept in the parent area.
class DownloadSettings {
  const DownloadSettings({
    this.wifiOnly = false,
    this.mobileConfirmBytes = 20 * 1024 * 1024,
  });

  /// True: full packs never download on mobile data. False: ask the parent first above
  /// [mobileConfirmBytes].
  final bool wifiOnly;
  final int mobileConfirmBytes;
}

enum DownloadStatus {
  done,

  /// Mobile data and the pack is above the size limit: ask the parent, then retry with
  /// `parentApproved: true`.
  needsParentApproval,

  /// Wi-Fi only is set and the device is on mobile data.
  blockedWifiOnly,
  offline,

  /// The pack needs a purchase that is not confirmed.
  notPurchased,
  failed,
}

class DownloadResult {
  const DownloadResult(this.status, [this.code]);
  final DownloadStatus status;
  final String? code;
  bool get ok => status == DownloadStatus.done;
}

/// The static server source: `<base_url><app_id>/index.json` and `index.sig`, then the files the
/// index lists. HTTPS only, one fixed host, no personal data sent.
class ServerContentSource implements ContentSource {
  ServerContentSource({
    required String baseUrl,
    required this.appId,
    required this.fetcher,
    required this.store,
    required this.signing,
  }) : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/') {
    if (_base.scheme != 'https' || _base.host.isEmpty) {
      throw ArgumentError('content base_url must be https: $baseUrl');
    }
  }

  final String appId;
  final ContentFetcher fetcher;
  final ContentStore store;
  final SigningConfig signing;
  final Uri _base;

  static const String _indexName = 'index.json';
  static const String _sigName = 'index.sig';
  static const String _trustName = 'trust.json';

  Uri _url(String path) => _base.resolve('$appId/$path');

  /// The verified cached index (empty when none, or when it no longer verifies).
  Future<ContentIndex> cachedIndex() async {
    final bytes = await store.read(_indexName);
    if (bytes == null) return ContentIndex.empty(appId);
    try {
      final sig = await store.read(_sigName);
      final trust = await _trust();
      await _verifyAuthenticity(bytes, sig, trust);
      final index = ContentIndex.parse(bytes);
      return index.app == appId ? index : ContentIndex.empty(appId);
    } on ContentException {
      return ContentIndex.empty(appId);
    }
  }

  Future<({bool seenSigned, int version})> _trust() async {
    final raw = await store.read(_trustName);
    if (raw == null) return (seenSigned: false, version: 0);
    try {
      final j = jsonDecode(utf8.decode(raw)) as Map;
      return (
        seenSigned: j['seen_signed'] == true,
        version: (j['version'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      return (seenSigned: false, version: 0);
    }
  }

  /// Signature policy. Returns true when the index was verified as signed.
  Future<bool> _verifyAuthenticity(
    Uint8List bytes,
    Uint8List? sig,
    ({bool seenSigned, int version}) trust,
  ) async {
    final needSig = signing.enabled || trust.seenSigned;
    if (sig == null) {
      if (needSig) {
        throw const ContentException(
          'unsigned',
          'a signed index is required here',
        );
      }
      return false;
    }
    if (!signing.enabled) {
      if (trust.seenSigned) {
        // A signed index was seen before, but there is no key to check this one: no downgrade.
        throw const ContentException('unsigned', 'cannot verify without a key');
      }
      return false; // no key set yet: accepted as unsigned
    }
    final ok = await verifyIndex(bytes, utf8.decode(sig), signing.publicKey);
    if (!ok) {
      throw const ContentException('bad_signature', 'index signature is wrong');
    }
    return true;
  }

  @override
  Future<List<PackEntry>> listPacks() async => (await cachedIndex()).packs;

  @override
  Future<UpdateResult> checkForUpdates() async {
    try {
      final trust = await _trust();
      final bytes = await fetcher.get(_url(_indexName));
      Uint8List? sig;
      if (signing.enabled || trust.seenSigned) {
        sig = await fetcher.get(_url(_sigName));
      }
      final signed = await _verifyAuthenticity(bytes, sig, trust);
      final index = ContentIndex.parse(bytes);
      if (index.app != appId) {
        return const UpdateResult(UpdateStatus.rejected, 'wrong_app');
      }
      final cached = await cachedIndex();
      if (index.version < cached.version) {
        return const UpdateResult(UpdateStatus.rollbackIgnored);
      }
      if (index.version == cached.version && cached.version > 0) {
        return const UpdateResult(UpdateStatus.upToDate);
      }
      await store.writeAll({
        _indexName: bytes,
        if (sig != null && signed) _sigName: sig,
        _trustName: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'seen_signed': trust.seenSigned || signed,
              'version': index.version,
              'key_id': signing.keyId,
            }),
          ),
        ),
      });
      return const UpdateResult(UpdateStatus.updated);
    } on ContentException catch (e) {
      return UpdateResult(UpdateStatus.rejected, e.code);
    } on Object {
      return const UpdateResult(UpdateStatus.failed, 'network');
    }
  }

  /// True when every cached file of [entry]'s [part] exists (the pack file and, for the full
  /// part, every asset).
  Future<bool> isCached(PackEntry entry, PackPart part) async {
    final ref = entry.fileFor(part);
    if (ref == null) return false;
    for (final r in [ref, if (part == PackPart.full) ...entry.assets]) {
      if (await store.read(r.path) == null) return false;
    }
    return true;
  }

  @override
  Future<ContentPack?> loadPack(
    String id, {
    PackPart part = PackPart.full,
  }) async {
    final entry = (await cachedIndex()).pack(id);
    final ref = entry?.fileFor(part);
    if (entry == null || ref == null) return null;
    final bytes = await store.read(ref.path);
    if (bytes == null) return null;
    try {
      ref.verify(bytes);
    } on ContentException {
      return null;
    }
    return ContentPack(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  }

  /// Downloads one part of [entry] into the cache. Every file is checked against the index
  /// first and nothing is stored unless all of them are complete and correct.
  /// Previews download on any connection; full packs follow [settings].
  Future<DownloadResult> download(
    PackEntry entry,
    PackPart part, {
    required ConnectionKind connection,
    DownloadSettings settings = const DownloadSettings(),
    bool parentApproved = false,
  }) async {
    final ref = entry.fileFor(part);
    if (ref == null) {
      return const DownloadResult(DownloadStatus.failed, 'no_file');
    }
    if (connection == ConnectionKind.offline) {
      return const DownloadResult(DownloadStatus.offline);
    }
    if (part == PackPart.full && connection == ConnectionKind.mobile) {
      if (settings.wifiOnly) {
        return const DownloadResult(DownloadStatus.blockedWifiOnly);
      }
      if (entry.sizeOf(part) > settings.mobileConfirmBytes && !parentApproved) {
        return const DownloadResult(DownloadStatus.needsParentApproval);
      }
    }
    try {
      final files = <String, Uint8List>{};
      for (final r in [ref, if (part == PackPart.full) ...entry.assets]) {
        final bytes = await fetcher.get(_url(r.path));
        r.verify(bytes);
        files[r.path] = bytes;
      }
      await store.writeAll(files);
      return const DownloadResult(DownloadStatus.done);
    } on ContentException catch (e) {
      return DownloadResult(DownloadStatus.failed, e.code);
    } on Object {
      return const DownloadResult(DownloadStatus.failed, 'network');
    }
  }
}
