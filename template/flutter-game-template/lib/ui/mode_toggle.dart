import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import 'kit/ds_buttons.dart';
import 'test_ids.dart';
import 'theme/app_theme.dart';

/// Game / Study switch for the top bar. Remembers the child's last mode. While a parent has
/// locked the child to one mode it shows only that mode with a lock icon and cannot switch
/// (the lock is changed in the parent area, behind the parent gate).
class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final locked = child.lockedMode;
    final mode = child.effectiveMode;
    Widget option(LearnMode m, Key key, String label) {
      final on = m == mode;
      return Semantics(
        button: true,
        selected: on,
        label: locked == null ? label : '$label mode, locked by a grown-up',
        excludeSemantics: true,
        onTap: on ? null : () => s.profile.setChildMode(child.id, m),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(999),
          onTap: locked != null || on
              ? null
              : () => s.profile.setChildMode(child.id, m),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.minTouch),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: t.sp('md')),
              decoration: BoxDecoration(
                color: on ? t.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: t.styles['caption']!.copyWith(
                  color: on ? t.onPrimary : t.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: TestIds.modeToggle,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked != null) ...[
            Padding(
              padding: EdgeInsets.only(left: t.sp('sm')),
              child: Semantics(
                label: 'Locked by a grown-up',
                excludeSemantics: true,
                child: DsIcon('lock', key: TestIds.modeLock, size: 16),
              ),
            ),
            option(
              locked,
              locked == LearnMode.game ? TestIds.modeGame : TestIds.modeStudy,
              locked == LearnMode.game ? 'Game' : 'Study',
            ),
          ] else ...[
            option(LearnMode.game, TestIds.modeGame, 'Game'),
            option(LearnMode.study, TestIds.modeStudy, 'Study'),
          ],
        ],
      ),
    );
  }
}
