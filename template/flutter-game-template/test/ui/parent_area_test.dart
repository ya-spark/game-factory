import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/purchase/parent_gate_guard.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

const _cfg = '''
app:
  id: me
  display_name: Me
  package_name: com.x.me
admob:
  debug:
    app_id: ca-app-pub-3940256099942544~1
    banner: ca-app-pub-3940256099942544/1
    interstitial: ca-app-pub-3940256099942544/2
    rewarded: ca-app-pub-3940256099942544/3
  release:
    app_id: PLACEHOLDER_A
    banner: PLACEHOLDER_B
    interstitial: PLACEHOLDER_C
    rewarded: PLACEHOLDER_D
content:
  enabled: true
''';

Future<Services> _services(ParentGateGuard guard) async {
  final base = await buildFakeServices(parentGate: guard);
  return Services(
    config: AppConfig.fromYamlString(_cfg),
    catalog: base.catalog,
    identity: base.identity,
    saves: base.saves,
    leaderboard: base.leaderboard,
    ads: base.ads,
    purchases: base.purchases,
    notifications: base.notifications,
    analytics: base.analytics,
    remoteConfig: base.remoteConfig,
    profile: base.profile,
    share: base.share,
    audio: base.audio,
    parentGate: guard,
  );
}

void main() {
  Future<void> pump(WidgetTester tester, Services s) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GameApp(services: s));
    await tester.pump();
  }

  testWidgets('first launch: make a player, pick a year, reach home', (
    tester,
  ) async {
    final s = await _services(ParentGateGuard());
    await pump(tester, s);
    expect(find.byKey(TestIds.pickerNickname), findsOneWidget);
    expect(find.textContaining('real name'), findsOneWidget);
    await tester.enterText(find.byKey(TestIds.pickerNickname), 'Mia');
    await tester.tap(find.byKey(TestIds.pickerYear(3)));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.pickerSave));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
    expect(s.profile.children.single.year, 3);
  });

  testWidgets(
    'the picker shows on every launch and the parent area needs the gate',
    (tester) async {
      final guard = ParentGateGuard();
      final s = await _services(guard);
      await s.profile.addChild('Mia', year: 3);
      await pump(tester, s);
      // picker, not home
      expect(find.byKey(TestIds.homePlay), findsNothing);
      expect(find.byKey(TestIds.pickerChild('p1')), findsOneWidget);
      expect(find.byKey(TestIds.parentArea), findsNothing);

      // cancelling the gate keeps the parent area closed
      await tester.tap(find.byKey(TestIds.pickerParent));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      await tester.tap(find.byKey(TestIds.gateCancel));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.parentArea), findsNothing);

      // a wrong answer does not open it either
      await tester.tap(find.byKey(TestIds.pickerParent));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TestIds.gateAnswer), '1');
      await tester.tap(find.byKey(TestIds.gateSubmit));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.parentArea), findsNothing);

      // the right answer opens it
      await tester.enterText(
        find.byKey(TestIds.gateAnswer),
        '${guard.a * guard.b}',
      );
      await tester.tap(find.byKey(TestIds.gateSubmit));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.parentArea), findsOneWidget);

      // change the year and the lock for the child
      await tester.tap(find.byKey(TestIds.parentLockStudy));
      await tester.pumpAndSettle();
      expect(s.profile.children.single.lockedMode?.name, 'study');
      await tester.tap(find.byKey(TestIds.parentWifiOnly));
      await tester.pumpAndSettle();
      expect(s.profile.data.downloadWifiOnly, isTrue);
      expect(s.profile.data.spacedReview, isTrue);
      await tester.tap(find.byKey(TestIds.parentSpacedReview));
      await tester.pumpAndSettle();
      expect(s.profile.data.spacedReview, isFalse);

      // delete the child
      await tester.ensureVisible(find.byKey(TestIds.parentDelete));
      await tester.tap(find.byKey(TestIds.parentDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TestIds.parentDeleteConfirm));
      await tester.pumpAndSettle();
      expect(s.profile.children, isEmpty);
    },
  );

  testWidgets('choosing a child on the picker opens home', (tester) async {
    final s = await _services(ParentGateGuard());
    await s.profile.addChild('Mia', year: 3);
    await pump(tester, s);
    await tester.tap(find.byKey(TestIds.pickerChild('p1')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });
}
