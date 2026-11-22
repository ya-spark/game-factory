import 'dart:io';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_judge_bot/judge_bot.dart';

ContentItem mcq({
  Object correct = 1,
  List<String> options = const ['a', 'b', 'c', 'd'],
  String prompt = 'Pick',
  String explanation = 'e',
}) => ContentItem({
  'id': 'a.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': explanation,
  'prompt': prompt,
  'options': options,
  'correct': correct,
});

ContentItem other(Map<String, dynamic> j) => ContentItem({
  'id': 'o.1',
  'seq': 1,
  'difficulty': 1,
  'explanation': 'e',
  ...j,
});

void main() {
  group('Judge bot rules: levels', () {
    test('younger no timer, older 10 s, hard 6 s, study never timed', () {
      expect(
        JudgeSettings.forLevel(const MiniGameLevel.younger()).secondsPerQuestion,
        0,
      );
      expect(
        JudgeSettings.forLevel(const MiniGameLevel.older()).secondsPerQuestion,
        10,
      );
      expect(
        JudgeSettings.forLevel(const MiniGameLevel.older(harder: true))
            .secondsPerQuestion,
        6,
      );
      final study = JudgeSettings.forLevel(
        const MiniGameLevel.older(),
        study: true,
      );
      expect(study.secondsPerQuestion, 0);
      expect(study.autoMove, isFalse);
    });

    test('only the older level moves on by itself', () {
      expect(JudgeSettings.forLevel(const MiniGameLevel.younger()).autoMove, isFalse);
      expect(JudgeSettings.forLevel(const MiniGameLevel.older()).autoMove, isTrue);
      expect(judgeAutoMove, const Duration(milliseconds: 1200));
    });
  });

  group('Judge bot rules: claims', () {
    test('a native True/False item keeps its prompt and authored truth', () {
      for (final truth in [true, false]) {
        final item = mcq(
          options: ['True', 'False'],
          correct: truth ? 0 : 1,
          prompt: 'A square has four sides.',
        );
        expect(isTrueFalseItem(item), isTrue);
        final c = buildClaim(item, Random(1))!;
        expect(c.shown, 'A square has four sides.');
        expect(c.question, c.shown);
        expect(c.isTrue, truth);
        expect(c.rightAnswer, truth ? 'True' : 'False');
        expect(c.derived, isFalse);
        expect(c.feedback, startsWith(truth ? 'True.' : 'False.'));
      }
    });

    test('an mcq item gives a true claim with the right option and a false one with a wrong option', () {
      var sawTrue = false, sawFalse = false;
      for (var seed = 0; seed < 40; seed++) {
        final c = buildClaim(mcq(), Random(seed))!;
        expect(c.derived, isTrue);
        expect(c.question, 'Pick');
        expect(c.rightAnswer, 'b');
        expect(c.shown, 'The answer is: ${c.claimed}');
        expect(c.isTrue, c.claimed == 'b');
        if (!c.isTrue) expect(['a', 'c', 'd'], contains(c.claimed));
        sawTrue |= c.isTrue;
        sawFalse |= !c.isTrue;
      }
      expect(sawTrue && sawFalse, isTrue);
    });

    test('wantTrue decides the claim; no run-on "Answer:" line any more', () {
      final t = buildClaim(mcq(), Random(3), wantTrue: true)!;
      final f = buildClaim(mcq(), Random(3), wantTrue: false)!;
      expect(t.isTrue, isTrue);
      expect(f.isTrue, isFalse);
      expect(t.shown, isNot(contains('Pick')));
      expect(t.shown, isNot(contains(' Answer: ')));
    });

    test('a plain maths question becomes "10 x 7 = 70?" and the feedback names it', () {
      final item = mcq(
        prompt: 'What is 10 x 7?',
        options: ['63', '70', '77', '17'],
        correct: 1,
      );
      final t = buildClaim(item, Random(1), wantTrue: true)!;
      expect(t.shown, '10 x 7 = 70?');
      expect(t.question, 'What is 10 x 7?');
      expect(t.feedback, 'True. 10 x 7 is 70.');
      final f = buildClaim(item, Random(1), wantTrue: false)!;
      expect(f.shown, matches(RegExp(r'^10 x 7 = (63|77|17)\?$')));
      expect(f.feedback, startsWith('False. The claim was '));
      expect(f.feedback, endsWith('10 x 7 is 70.'));
      expect(f.rightAnswer, '70');
    });

    test('other questions say "The answer is" and the feedback quotes the question', () {
      final c = buildClaim(
        mcq(prompt: 'Which is a prime number?', options: ['9', '7', '8', '10']),
        Random(2),
        wantTrue: false,
      )!;
      expect(c.shown, startsWith('The answer is: '));
      expect(c.feedback, contains('"Which is a prime number"'));
      expect(c.feedback, contains('is 7.'));
    });

    test('a distractor equal to the right option (any case) is never the false claim', () {
      for (var seed = 0; seed < 30; seed++) {
        final c = buildClaim(
          mcq(options: ['Cat', 'cat', 'Dog', 'dog'], correct: 0),
          Random(seed),
          wantTrue: false,
        )!;
        expect(c.isTrue, isFalse);
        expect(c.claimed!.toLowerCase(), isNot('cat'));
      }
    });

    test('no usable distractor falls back to the true claim', () {
      final c = buildClaim(
        mcq(options: ['x', 'x'], correct: 0),
        Random(1),
        wantTrue: false,
      )!;
      expect(c.isTrue, isTrue);
    });

    test('items that cannot be used give null and are not claimable', () {
      expect(buildClaim(other({'type': 'numeric', 'prompt': 'p', 'answer': 3}), Random(1)), isNull);
      expect(buildClaim(mcq(options: ['only']), Random(1)), isNull);
      expect(isClaimable(mcq(correct: 9)), isFalse);
      expect(isClaimable(mcq()), isTrue);
    });
  });

  group('Judge bot rules: balance', () {
    List<ContentItem> derived(int n) => [for (var i = 0; i < n; i++) mcq()];

    test('derived tickets are 40 to 60 percent true and no verdict runs over 3', () {
      for (var seed = 0; seed < 60; seed++) {
        for (final n in [4, 5, 8, 10, 12]) {
          final d = ClaimDealer(derived(n), Random(seed));
          final trues = d.plan.where((x) => x).length;
          expect(trues / n, inInclusiveRange(0.4 - 1e-9, 0.6 + 1e-9), reason: 'n=$n seed=$seed');
          expect(longestRun(d.plan), lessThanOrEqualTo(judgeMaxRun));
          for (var i = 0; i < n; i++) {
            expect(d.claimAt(i)!.isTrue, d.plan[i]);
          }
        }
      }
    });

    test('native items keep their truth inside the plan', () {
      final items = [
        mcq(options: ['True', 'False'], correct: 0),
        mcq(),
        mcq(options: ['True', 'False'], correct: 1),
        mcq(),
      ];
      final d = ClaimDealer(items, Random(5));
      expect(d.claimAt(0)!.isTrue, isTrue);
      expect(d.claimAt(2)!.isTrue, isFalse);
    });

    test('the same seed deals the same tickets, and a dealt ticket never changes', () {
      List<String> run(int seed) {
        final d = ClaimDealer(derived(8), Random(seed));
        return [for (var i = 0; i < 8; i++) d.claimAt(i)!.shown];
      }

      expect(run(7), run(7));
      final d = ClaimDealer(derived(8), Random(1));
      final first = d.claimAt(3)!;
      expect(identical(d.claimAt(3), first), isTrue);
    });
  });

  group('Judge bot rules: score, streak, evidence', () {
    test('score is 10, older plus 2 per streak step up to 5, fast adds 2', () {
      expect(judgeScore(streak: 0, older: false), 10);
      expect(judgeScore(streak: 9, older: false), 10);
      expect(judgeScore(streak: 0, older: true), 10);
      expect(judgeScore(streak: 3, older: true), 16);
      expect(judgeScore(streak: 9, older: true), 20);
      expect(judgeScore(streak: 1, older: true, fast: true), 14);
    });

    test('fast means the first half of the timer', () {
      expect(isFastAnswer(4.9, 10), isTrue);
      expect(isFastAnswer(5.1, 10), isFalse);
      expect(isFastAnswer(0, 0), isFalse);
    });

    test('bulbs: 5 then a gold row', () {
      expect(bulbsFor(0), (lit: 0, gold: false));
      expect(bulbsFor(3), (lit: 3, gold: false));
      expect(bulbsFor(5), (lit: 5, gold: false));
      expect(bulbsFor(6), (lit: 1, gold: true));
      expect(bulbsFor(10), (lit: 5, gold: true));
    });

    test('light evidence: a right answer counts from the second in a row; a miss always counts', () {
      expect(countsAsSkillEvidence(correct: true, streakBefore: 0), isFalse);
      expect(countsAsSkillEvidence(correct: true, streakBefore: 1), isTrue);
      expect(countsAsSkillEvidence(correct: false, streakBefore: 0), isTrue);
    });
  });

  group('Judge bot: migration and purity', () {
    test('true_false became judge_bot (scores and progress follow)', () {
      expect(renamedGameIds['true_false'], 'judge_bot');
      expect(HowToPlayCatalogue.forGame('judge_bot')!.title, 'Judge bot');
      expect(HowToPlayCatalogue.forGame('true_false'), isNull);
      expect(judgeBotId, 'judge_bot');
    });

    test('the rules file has no Flutter import', () {
      final src = File('lib/src/rules/judge_rules.dart').readAsStringSync();
      expect(src, isNot(contains('package:flutter')));
      expect(src, isNot(contains('dart:ui')));
    });

    test('the lamp colours give white text at least 4.5:1 and the ticket 7:1', () {
      double lum(Color c) => c.computeLuminance();
      double ratio(Color a, Color b) {
        final l1 = max(lum(a), lum(b)), l2 = min(lum(a), lum(b));
        return (l1 + 0.05) / (l2 + 0.05);
      }

      const white = Color(0xFFFFFFFF);
      expect(ratio(white, judgeTrueGreen), greaterThanOrEqualTo(4.5));
      expect(ratio(white, judgeFalseRed), greaterThanOrEqualTo(4.5));
      expect(ratio(judgeInk, judgeTicket), greaterThanOrEqualTo(7));
    });
  });
}
