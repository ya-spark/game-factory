import '../config/app_config.dart';

/// Fixed height reserved for a web ad slot, so the layout does not jump when an ad loads.
const double adSenseSlotHeight = 100;

/// One AdSense unit to request: which placement, with which attributes. Pure Dart.
class AdSenseUnit {
  const AdSenseUnit({
    required this.placement,
    required this.publisherId,
    required this.slotId,
    required this.testMode,
    required this.ageTreatment,
  });

  final AdPlacement placement;
  final String publisherId;
  final String slotId;
  final bool testMode;
  final AgeTreatment ageTreatment;

  /// Child and teen treatment: non-personalised ads only.
  bool get nonPersonalised => ageTreatment != AgeTreatment.none;

  /// Attributes of the `<ins class="adsbygoogle">` element. The age treatment tag goes on every
  /// ad element ("Tag for age treatment", AdSense help); `none` adds no tag (unspecified).
  Map<String, String> get attributes => {
    'data-ad-client': publisherId,
    'data-ad-slot': slotId,
    if (ageTreatment != AgeTreatment.none)
      'data-tag-for-age-treatment': '${ageTreatment.attributeValue}',
    if (testMode) 'data-adtest': 'on',
  };
}

/// Decides which placement shows an ad on web, and with which attributes. Pure Dart, so the
/// rules are unit-tested without a browser.
abstract final class AdSensePlan {
  /// Null when nothing may be requested: AdSense off, a placeholder publisher id, banners off
  /// in the config, or no slot id for the placement. Only the three placements exist, so none
  /// is ever in play.
  static AdSenseUnit? unitFor(
    AdSenseConfig config,
    AdPlacement placement, {
    bool bannerEnabled = true,
  }) {
    if (!bannerEnabled || !config.isLive) return null;
    final slot = config.slotFor(placement);
    if (slot == null) return null;
    return AdSenseUnit(
      placement: placement,
      publisherId: config.publisherId,
      slotId: slot,
      testMode: config.testMode,
      ageTreatment: config.ageTreatment,
    );
  }

  /// The "Ad privacy choices" row in Settings: web only, and only when AdSense is switched on.
  static bool showPrivacyChoicesRow(
    AdSenseConfig config, {
    required bool web,
  }) => web && config.enabled;
}
