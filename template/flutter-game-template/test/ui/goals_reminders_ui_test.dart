import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/parent_area_screen.dart';
import 'package:flutter_game_template/ui/settings_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<Services> _open(
  WidgetTester tester,
  Widget screen, {
  FakeNotificationService? n,
  bool parentArea = true,
  bool settingsRow = true,
}) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(
    contentEnabled: true,
    goalsParentArea: parentArea,
    settingsReminderRow: settingsRow,
    notifications: n,
  );
  await s.profile.addChild('Mia');
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
  return s;
}

void main() {
  testWidgets('Parent area: a goal preset is saved per child', (tester) async {
    final s = await _open(tester, const ParentAreaScreen());
    expect(find.byKey(TestIds.parentGoalSummary), findsOneWidget);
    await tester.tap(find.byKey(TestIds.parentGoalPreset('big')));
    await tester.pump();
    expect(s.profile.children.single.goalPreset, GoalPreset.big);
    expect(find.textContaining('8 items a day, 40 a week'), findsOneWidget);
  });

  testWidgets('Parent area: reminders switch, time and days', (tester) async {
    final n = FakeNotificationService();
    final s = await _open(tester, const ParentAreaScreen(), n: n);
    expect(find.byKey(TestIds.parentReminderTime), findsNothing);
    await tester.tap(find.byKey(TestIds.parentRemindersSwitch));
    await tester.pump();
    expect(s.profile.data.remindersOn, isTrue);
    expect(n.permissionAsks, 1);
    await tester.tap(find.byKey(TestIds.parentReminderDay(6)));
    await tester.pump();
    expect(s.profile.data.reminderDays, {1, 2, 3, 4, 5, 7});
    await tester.tap(find.byKey(TestIds.parentReminderTime));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.parentReminderTimeOption(6 * 60)), findsNothing);
    expect(find.byKey(TestIds.parentReminderTimeOption(7 * 60)), findsWidgets);
    expect(
      find.byKey(TestIds.parentReminderTimeOption(20 * 60 + 30)),
      findsNothing,
    );
    await tester.tap(find.byKey(TestIds.parentReminderTimeOption(8 * 60)).last);
    await tester.pumpAndSettle();
    expect(s.profile.data.reminderHour, 8);
  });

  testWidgets('Parent area: permission denied shows one calm line', (
    tester,
  ) async {
    final n = FakeNotificationService(permission: false);
    final s = await _open(tester, const ParentAreaScreen(), n: n);
    await tester.tap(find.byKey(TestIds.parentRemindersSwitch));
    await tester.pump();
    expect(s.profile.data.remindersOn, isFalse);
    expect(find.byKey(TestIds.parentRemindersDenied), findsOneWidget);
    expect(n.permissionAsks, 1);
  });

  testWidgets('Settings row: absent in Scout and Ranger, present otherwise', (
    tester,
  ) async {
    await _open(tester, const SettingsScreen(), settingsRow: false);
    expect(find.byKey(TestIds.settingsReminders), findsNothing);
  });

  testWidgets('Settings row: present in Champion', (tester) async {
    await _open(tester, const SettingsScreen());
    expect(find.byKey(TestIds.settingsReminders), findsOneWidget);
  });

  testWidgets('Without goals_reminders the Parent area is as before', (
    tester,
  ) async {
    await _open(tester, const ParentAreaScreen(), parentArea: false);
    expect(find.byKey(TestIds.parentRemindersSwitch), findsNothing);
    expect(find.byKey(TestIds.parentGoalSummary), findsNothing);
  });
}
