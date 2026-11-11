import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../test_ids.dart';

class ShopTab extends StatelessWidget {
  const ShopTab({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) =>
      const Center(key: TestIds.shopTab, child: Text('Shop'));
}
