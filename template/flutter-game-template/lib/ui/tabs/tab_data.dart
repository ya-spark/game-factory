import 'package:flutter/widgets.dart';

import '../../core/services.dart';
import '../../engine/engine.dart';

typedef OpenItemsLoader = Future<List<PoolItem>> Function(String childId);
typedef PacksLoader = Future<List<LoadedPack>> Function();

/// Where the tabs read the open items and packs from. Defaults to the app's `LearningService`;
/// tests pass their own.
class TabLoaders {
  const TabLoaders({required this.openItems, required this.packs});
  final OpenItemsLoader openItems;
  final PacksLoader packs;

  factory TabLoaders.of(BuildContext context) {
    final learning = ServicesScope.of(context).learning;
    return TabLoaders(
      openItems: (id) async => learning?.openItems(id) ?? const <PoolItem>[],
      packs: () async => learning?.loadedPacks() ?? const <LoadedPack>[],
    );
  }
}

/// "subject/year/topic" (a `topicKey`) split back into its parts.
({String subject, int year, String topic}) splitTopicKey(String key) {
  final p = key.split('/');
  return (subject: p[0], year: int.parse(p[1]), topic: p.sublist(2).join('/'));
}

/// "adjectives_adverbs" tidied for display: underscores to spaces, first letter capital.
String tidyTopicId(String id) {
  final s = id.replaceAll('_', ' ').trim();
  return s.isEmpty ? id : s[0].toUpperCase() + s.substring(1);
}

/// The name to show for a topic: the title of its pack (which carries the display name from
/// `content/topics.yaml`), or the tidied id when no pack of that topic is loaded.
String topicDisplayName(
  Iterable<LoadedPack> packs,
  String subject,
  int year,
  String topic,
) {
  LoadedPack? best;
  for (final lp in packs) {
    final p = lp.pack;
    if (p.subject != subject || p.year != year || p.topic != topic) continue;
    if (p.title.trim().isEmpty) continue;
    // Prefer the base (non-extra) pack's title.
    if (best == null || (best.pack.isExtra && !p.isExtra)) best = lp;
  }
  return best?.pack.title.trim() ?? tidyTopicId(topic);
}
