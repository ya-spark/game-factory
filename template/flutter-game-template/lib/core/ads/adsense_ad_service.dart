import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../config/app_config.dart';
import 'ad_service.dart';
import 'ad_slot_frame.dart';
import 'adsense_plan.dart';

/// `window.adsbygoogle`, created when the (async) vendor script has not defined it yet, exactly
/// like Google's own snippet `(adsbygoogle = window.adsbygoogle || []).push({})`.
JSObject _queue() {
  final w = web.window as JSObject;
  var q = w.getProperty<JSObject?>('adsbygoogle'.toJS);
  if (q == null) {
    q = JSArray<JSAny?>() as JSObject;
    w.setProperty('adsbygoogle'.toJS, q);
  }
  return q;
}

@JS('googlefc')
external JSObject? get _googlefc;

/// Google AdSense for the web copy: the only file (besides the generated `web/index.html`, which
/// carries the script tag) that knows the vendor. Banner/display units only at the menu, before a
/// game and after a game, in a fixed-height slot outside the game canvas. No rewarded ad, no
/// interstitial, no ads-removed state (a browser has no real-money items).
///
/// Off by default: the script tag is written only for `adsense.enabled` with a real publisher id
/// (`scripts/web_shell.py`); without it [adsEnabled] is false and every banner is an empty box.
class AdSenseAdService implements AdService {
  AdSenseAdService({required this.config, required this.bannerEnabled});

  final AdSenseConfig config;
  final bool bannerEnabled;

  bool _scriptPresent = false;
  int _nextViewId = 0;

  @override
  Future<void> initialize() async {
    if (!config.isLive) return;
    _scriptPresent =
        web.document.querySelector('script[src*="adsbygoogle.js"]') != null;
    if (!_scriptPresent) return;
    // Child and teen treatment: non-personalised ads only, set before the first request.
    if (config.nonPersonalisedOnly) {
      _queue().setProperty('requestNonPersonalizedAds'.toJS, 1.toJS);
    }
  }

  @override
  bool get adsEnabled => config.isLive && _scriptPresent;

  /// No "remove ads" on web: nothing to remove.
  @override
  set adsRemoved(bool value) {}

  @override
  bool get isRewardedReady => false;

  /// No rewarded ads on web (no Continue-by-ad).
  @override
  Future<bool> showRewarded(RewardedPlacement placement) async => false;

  @override
  Widget buildBanner(AdPlacement placement) {
    if (!adsEnabled) return const SizedBox.shrink();
    final unit = AdSensePlan.unitFor(
      config,
      placement,
      bannerEnabled: bannerEnabled,
    );
    if (unit == null) return const SizedBox.shrink();
    final viewType = 'adsense-${placement.configName}-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final holder = web.document.createElement('div') as web.HTMLElement;
      holder.style.width = '100%';
      holder.style.height = '${adSenseSlotHeight}px';
      final ins = web.document.createElement('ins') as web.HTMLElement;
      ins.className = 'adsbygoogle';
      ins.style.display = 'block';
      ins.style.width = '100%';
      ins.style.height = '${adSenseSlotHeight}px';
      for (final a in unit.attributes.entries) {
        ins.setAttribute(a.key, a.value);
      }
      holder.append(ins);
      try {
        _queue().callMethod('push'.toJS, JSObject());
      } catch (e) {
        debugPrint('AdSense: request failed: $e');
      }
      return holder;
    });
    return AdSlotFrame(
      placementName: placement.configName,
      child: HtmlElementView(viewType: viewType),
    );
  }

  /// True when Google's consent dialog (set up in the AdSense account) is present on the page.
  @override
  bool get privacyOptionsRequired => _googlefc != null;

  /// Re-opens Google's consent dialog; a no-op when there is none. No consent logic of ours.
  @override
  Future<void> showPrivacyOptions() async {
    final fc = _googlefc;
    if (fc == null) return;
    try {
      final queue = fc.getProperty<JSObject?>('callbackQueue'.toJS);
      final show = fc.getProperty<JSAny?>('showRevocationMessage'.toJS);
      if (queue != null && show != null) queue.callMethod('push'.toJS, show);
    } catch (e) {
      debugPrint('AdSense: consent dialog unavailable: $e');
    }
  }
}
