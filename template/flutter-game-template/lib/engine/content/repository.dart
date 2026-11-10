/// One view over the built-in and the downloaded content: which packs exist, which are on the
/// device, the newest verified version of each, and the daily update check. Pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'content_source.dart';
import 'models.dart';

/// A pack as the parent area and the game see it.
class CatalogPack {
  const CatalogPack({
    required this.entry,
    required this.builtIn,
    required this.cachedFull,
    required this.cachedPreview,
  });

  /// The newest entry known (built-in or from the cached server index).
  final PackEntry entry;

  /// A built-in copy exists (any version).
  final bool builtIn;
  final bool cachedFull;
  final bool cachedPreview;

  String get id => entry.id;
  bool get isExtra => entry.isExtra;
}

typedef OwnedCheck = bool Function(String productId);

class ContentRepository {
  ContentRepository({
    required this.builtIn,
    this.server,
    this.store,
    required this.isOwned,
    this.checkInterval = const Duration(days: 1),
  });

  final BuiltInContentSource builtIn;
  final ServerContentSource? server;

  /// Same store the server source uses; also keeps the time of the last update check.
  final ContentStore? store;

  /// True once Play Billing has confirmed the purchase of this product on this device.
  final OwnedCheck isOwned;
  final Duration checkInterval;

  List<BundleEntry> _bundles = const [];

  /// Bundles of the built-in and the cached server index (the server one wins per product id).
  /// Also refreshes the copy [owns] reads.
  Future<List<BundleEntry>> bundles() async {
    final byId = <String, BundleEntry>{
      for (final b in await builtIn.listBundles()) b.productId: b,
    };
    final srv = server;
    if (srv != null) {
      for (final b in await srv.listBundles()) {
        byId[b.productId] = b;
      }
    }
    return _bundles = byId.values.toList()
      ..sort((a, b) => a.productId.compareTo(b.productId));
  }

  /// Every product id the app should ask Play about: live extra packs and live bundles named
  /// in the index. A new pack needs no app update. Draft entries are left out.
  Future<Set<String>> productIds() async => {
    for (final c in await catalog())
      if (c.entry.productId != null && c.entry.isLive) c.entry.productId!,
    for (final b in await bundles())
      if (b.isLive) b.productId,
  };

  /// True when the pack's own product, or a bundle that lists the pack, is confirmed owned.
  /// Reads the bundles loaded last (see [bundles]); [catalog] and [loadForPlay] refresh them.
  bool owns(PackEntry e) {
    final pid = e.productId;
    if (pid == null) return false;
    if (isOwned(pid)) return true;
    return _bundles.any((b) => b.packs.contains(e.id) && isOwned(b.productId));
  }

  static const String _lastCheckName = 'last_check.json';

  /// Every pack: built-in ones plus those in the verified server index. The newest version of
  /// an id wins. Works offline.
  Future<List<CatalogPack>> catalog() async {
    await bundles();
    final byId = <String, PackEntry>{};
    final builtInIds = <String>{};
    for (final e in await builtIn.listPacks()) {
      byId[e.id] = e;
      builtInIds.add(e.id);
    }
    final srv = server;
    final cached = <String, ({bool full, bool preview})>{};
    if (srv != null) {
      for (final e in await srv.listPacks()) {
        final c = (
          full: await srv.isCached(e, PackPart.full),
          preview: await srv.isCached(e, PackPart.preview),
        );
        final have = byId[e.id];
        // A cached copy only counts when it is newer than the bundled one.
        if (have == null || e.version > have.version) {
          byId[e.id] = e;
          cached[e.id] = c;
        }
      }
    }
    final ids = byId.keys.toList()..sort();
    return [
      for (final id in ids)
        CatalogPack(
          entry: byId[id]!,
          builtIn: builtInIds.contains(id),
          cachedFull: cached[id]?.full ?? false,
          cachedPreview: cached[id]?.preview ?? false,
        ),
    ];
  }

  /// The pack to play, with what part it is. Built-in packs use the newest of the bundled and
  /// the downloaded copy. An extra pack is its full part once bought and downloaded, else its
  /// downloaded preview, else null.
  Future<({ContentPack pack, bool previewOnly})?> loadForPlay(
    CatalogPack c,
  ) async {
    final srv = server;
    await bundles();
    // A draft pack is not for sale yet: hidden, never played.
    if (!c.entry.isLive) return null;
    if (!c.isExtra) {
      if (srv != null && c.cachedFull) {
        final p = await srv.loadPack(c.id);
        if (p != null) return (pack: p, previewOnly: false);
      }
      final b = await builtIn.loadPack(c.id);
      return b == null ? null : (pack: b, previewOnly: false);
    }
    if (srv == null) return null;
    final owned = owns(c.entry);
    if (owned && c.cachedFull) {
      final p = await srv.loadPack(c.id);
      if (p != null) return (pack: p, previewOnly: false);
    }
    if (c.cachedPreview) {
      final p = await srv.loadPack(c.id, part: PackPart.preview);
      if (p != null) return (pack: p, previewOnly: true);
    }
    return null;
  }

  /// Every pack that can be played right now.
  Future<List<({ContentPack pack, bool previewOnly})>> loadAllForPlay() async {
    final out = <({ContentPack pack, bool previewOnly})>[];
    for (final c in await catalog()) {
      final l = await loadForPlay(c);
      if (l != null) out.add(l);
    }
    return out;
  }

  /// Downloads a part. The full part of an extra pack needs a confirmed purchase; a preview
  /// never does.
  Future<DownloadResult> download(
    CatalogPack c,
    PackPart part, {
    required ConnectionKind connection,
    DownloadSettings settings = const DownloadSettings(),
    bool parentApproved = false,
  }) async {
    final srv = server;
    if (srv == null) {
      return const DownloadResult(DownloadStatus.failed, 'no_server');
    }
    if (!c.entry.isLive) {
      return const DownloadResult(DownloadStatus.failed, 'draft');
    }
    await bundles();
    if (part == PackPart.full && c.isExtra && !owns(c.entry)) {
      return const DownloadResult(DownloadStatus.notPurchased);
    }
    return srv.download(
      c.entry,
      part,
      connection: connection,
      settings: settings,
      parentApproved: parentApproved,
    );
  }

  /// Update check on launch: at most once per [checkInterval], silent, failures ignored.
  /// After a new index arrives, newer versions of the built-in packs are downloaded when the
  /// connection allows it without asking.
  Future<UpdateResult> checkOnLaunch(
    DateTime now, {
    required ConnectionKind connection,
    DownloadSettings settings = const DownloadSettings(),
  }) async {
    final srv = server;
    final st = store;
    if (srv == null || connection == ConnectionKind.offline) {
      return const UpdateResult(UpdateStatus.failed, 'offline');
    }
    final last = await _lastCheck(st);
    if (last != null && now.difference(last) < checkInterval) {
      return const UpdateResult(UpdateStatus.upToDate, 'throttled');
    }
    final r = await srv.checkForUpdates();
    if (r.status != UpdateStatus.failed) await _writeLastCheck(st, now);
    if (r.status == UpdateStatus.updated) {
      final builtInVersions = {
        for (final e in await builtIn.listPacks()) e.id: e.version,
      };
      for (final e in await srv.listPacks()) {
        final v = builtInVersions[e.id];
        if (!e.isExtra && v != null && e.version > v) {
          await srv.download(
            e,
            PackPart.full,
            connection: connection,
            settings: settings,
          );
        }
      }
    }
    return r;
  }

  Future<DateTime?> _lastCheck(ContentStore? st) async {
    final raw = await st?.read(_lastCheckName);
    if (raw == null) return null;
    try {
      final ms = (jsonDecode(utf8.decode(raw)) as Map)['ms'] as int;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } on Object {
      return null;
    }
  }

  Future<void> _writeLastCheck(ContentStore? st, DateTime now) async {
    await st?.writeAll({
      _lastCheckName: Uint8List.fromList(
        utf8.encode(jsonEncode({'ms': now.millisecondsSinceEpoch})),
      ),
    });
  }
}
