import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/core/share/share_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/child_report.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

void main() {
  testWidgets('weekly report sections, share text and nickname switch', (
    tester,
  ) async {
    final share = FakeShareService();
    final s = await buildFakeServices(share: share, contentEnabled: true);
    final today = s.profile.today;
    final kid = (await s.profile.addChild('Kit'))!;
    await s.profile.setChildProgress(
      kid.id,
      const ChildProgress().record(
        PoolItem(
          item: ContentItem({
            'id': 'x1',
            'type': 'mcq',
            'seq': 1,
            'difficulty': 1,
            'explanation': 'e',
            'prompt': 'p',
            'options': ['a', 'b'],
            'correct': 0,
          }),
          packId: 'pk',
          subject: 'maths',
          year: 3,
          topic: 'T',
        ),
        correct: true,
        day: today,
      ),
    );
    final child = s.profile.children.firstWhere((c) => c.id == kid.id);
    expect(child.activity.days[today]!.answers, 1);

    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ChildReport(child: child)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final k in [
      TestIds.reportThisWeek,
      TestIds.reportLastWeek,
      TestIds.reportStrongest,
      TestIds.reportAttention,
      TestIds.reportShareName,
      TestIds.reportShare,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
    final sw = tester.widget<SwitchListTile>(
      find.byKey(TestIds.reportShareName),
    );
    expect(sw.value, shareNicknameDefault);

    await tester.ensureVisible(find.byKey(TestIds.reportShare));
    await tester.tap(find.byKey(TestIds.reportShare));
    await tester.pumpAndSettle();
    expect(share.sent, hasLength(1));
    expect(share.sent.first.text, contains('Answers: 1'));
    expect(share.sent.first.text.contains('Kit'), shareNicknameDefault);
    expect(share.sent.first.image, isNull);

    await tester.ensureVisible(find.byKey(TestIds.reportShareName));
    await tester.tap(find.byKey(TestIds.reportShareName));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.reportShare));
    await tester.pumpAndSettle();
    expect(share.sent.last.text.contains('Kit'), !shareNicknameDefault);
  });
}
