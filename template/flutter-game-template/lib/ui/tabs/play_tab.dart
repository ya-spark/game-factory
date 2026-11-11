import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';

class PlayTab extends StatelessWidget {
  const PlayTab({super.key, required this.child, required this.registry});
  final ChildProfile child;
  final MiniGameRegistry registry;

  @override
  Widget build(BuildContext context) =>
      const Center(key: TestIds.playTab, child: Text('Play'));
}
