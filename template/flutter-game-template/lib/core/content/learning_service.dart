import '../../engine/engine.dart';
import '../clock.dart';
import '../config/app_config.dart';
import '../profile/child_profile.dart';
import '../profile/profile_store.dart';
import '../purchase/purchase_service.dart';
import 'connectivity_probe.dart';

/// Glue between the content repository, the child profiles and purchases. UI calls this, never
/// the sources directly.
class LearningService {
  LearningService({
    required this.config,
    required this.profile,
    required this.repository,
    required this.connectivity,
    required this.purchases,
    Clock? clock,
  }) : _clock = clock ?? DateTime.now;

  final ContentConfig config;
  final ProfileStore profile;
  final ContentRepository repository;
  final ConnectivityProbe connectivity;
  final PurchaseService purchases;
  final Clock _clock;

  DownloadSettings get downloadSettings =>
      config.downloadSettings(wifiOnly: profile.data.downloadWifiOnly);

  /// The local date as a day number. Uses the profile's guarded clock.
  int get today => profile.today;

  /// Silent update check at most once a day. Never throws.
  Future<void> checkForUpdates() async {
    try {
      await repository.checkOnLaunch(
        _clock(),
        connection: await connectivity.current(),
        settings: downloadSettings,
      );
      await purchases.registerExtraProducts(await repository.productIds());
    } on Object {
      // silent: the app works offline from the built-in content
    }
  }

  Future<List<LoadedPack>> _loaded() async => [
    for (final l in await repository.loadAllForPlay())
      LoadedPack(l.pack, previewOnly: l.previewOnly),
  ];

  /// Opens today's items for the child (daily release of built-in content) and saves it.
  /// Needs the child's year; does nothing before the year is picked.
  Future<ChildProfile?> refreshRelease(String childId) async {
    final child = profile.children.where((c) => c.id == childId).firstOrNull;
    final year = child?.year;
    if (child == null || year == null) return child;
    final next = ReleaseEngine.refresh(
      child.progress,
      await _loaded(),
      year,
      today,
      config.dailyRelease,
    );
    await profile.setChildProgress(childId, next);
    return profile.children.firstWhere((c) => c.id == childId);
  }

  /// Items this child can open now.
  Future<List<PoolItem>> openItems(String childId) async {
    final child = profile.children.firstWhere((c) => c.id == childId);
    return OpenItems.compute(
      await _loaded(),
      child.progress,
      fullUnlock: profile.data.fullUnlock,
    );
  }

  /// Records one answer for a child.
  Future<void> recordAnswer(
    String childId,
    PoolItem item, {
    required bool correct,
  }) async {
    final child = profile.children.firstWhere((c) => c.id == childId);
    await profile.setChildProgress(
      childId,
      child.progress.record(item, correct: correct),
    );
  }

  // ---- parent area --------------------------------------------------------

  /// Packs for the parent area: the child's year only, or every year.
  Future<List<CatalogPack>> packsFor(
    int? year, {
    bool allYears = false,
  }) async => [
    for (final c in await repository.catalog())
      if (c.isExtra &&
          c.entry.isLive &&
          (allYears || year == null || c.entry.year == year))
        c,
  ];

  /// Live year bundles for the parent area: the child's year only, or every year.
  Future<List<BundleEntry>> bundlesFor(
    int? year, {
    bool allYears = false,
  }) async => [
    for (final b in await repository.bundles())
      if (b.isLive && (allYears || year == null || b.year == year)) b,
  ];

  /// Owned through its own product or a bundle that lists it.
  bool owns(CatalogPack c) => repository.owns(c.entry);

  bool ownsBundle(BundleEntry b) => profile.ownsPack(b.productId);

  Future<DownloadResult> downloadPreview(CatalogPack c) async => repository
      .download(c, PackPart.preview, connection: await connectivity.current());

  /// Full pack download. Returns `needsParentApproval` on mobile data above the size limit;
  /// call again with `parentApproved: true` after the grown-up agrees.
  Future<DownloadResult> downloadFull(
    CatalogPack c, {
    bool parentApproved = false,
  }) async => repository.download(
    c,
    PackPart.full,
    connection: await connectivity.current(),
    settings: downloadSettings,
    parentApproved: parentApproved,
  );

  /// Starts the purchase (the caller has already passed the parent gate).
  Future<void> buy(String productId) => purchases.buy(productId);

  /// Restore. The products named in the index are registered first, so what Play returns is
  /// checked against the current index: an owned id that is not in the index has no effect, and
  /// a bundle restores every pack it lists.
  Future<void> restorePurchases() async {
    try {
      await purchases.registerExtraProducts(await repository.productIds());
    } on Object {
      // restore still runs without the index
    }
    await purchases.restore();
  }
}
