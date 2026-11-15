import 'package:flutter/widgets.dart';

import 'adsense_plan.dart';

/// Key of the web ad slot of a placement (also `TestIds.adSlot`).
Key adSlotKey(String placementName) => Key('ads.slot.$placementName');

/// A web ad slot: a fixed-height box outside the game canvas that hosts the ad element, with
/// breathing room so it never sits next to a tap target. Pure Flutter (the platform view is
/// passed in), so widget tests can use it.
class AdSlotFrame extends StatelessWidget {
  const AdSlotFrame({
    super.key,
    required this.placementName,
    required this.child,
  });

  final String placementName;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: SizedBox(
      key: adSlotKey(placementName),
      height: adSenseSlotHeight,
      width: double.infinity,
      child: ExcludeSemantics(child: child),
    ),
  );
}
