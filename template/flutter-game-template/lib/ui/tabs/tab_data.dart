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
