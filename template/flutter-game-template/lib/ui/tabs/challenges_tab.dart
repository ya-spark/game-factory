import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../test_ids.dart';

class ChallengesTab extends StatelessWidget {
  const ChallengesTab({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) =>
      const Center(key: TestIds.challengesTab, child: Text('Challenges'));
}
