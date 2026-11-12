import 'package:flutter/material.dart';

import '../core/services.dart';
import 'child_report.dart';
import 'test_ids.dart';

/// A plain Progress page for the teen app (Champion): this week's time and accuracy by topic for
/// the player using the device. No adult check, no reset, no purchases.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: s.profile,
      builder: (context, _) {
        final child = s.profile.activeChild;
        return Scaffold(
          key: TestIds.progressScreen,
          appBar: AppBar(title: const Text('Progress')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (child == null)
                const Text('Pick a player to see progress.')
              else
                ChildReport(child: child),
            ],
          ),
        );
      },
    );
  }
}
