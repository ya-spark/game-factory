import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every entry has 1 to 3 rules and 2 or 3 tips, and no duplicate ids',
    () {
      final ids = <String>{};
      for (final g in GameRulesCatalogue.all) {
        expect(ids.add(g.id), isTrue, reason: 'duplicate ${g.id}');
        expect(g.title, isNotEmpty);
        expect(g.rules.length, inInclusiveRange(1, 3), reason: g.id);
        expect(g.tips.length, inInclusiveRange(2, 3), reason: g.id);
      }
      for (final id in [
        quickQuizId,
        memoryMatchId,
        sortBinsId,
        seriesBuilderId,
        wordBuilderId,
        trueFalseId,
        clozeFixId,
        equationBuilderId,
        wordGridId,
        balloonPopId,
        doorRunnerId,
        tugOfWarId,
        flashReviewId,
      ]) {
        expect(GameRulesCatalogue.forGame(id), isNotNull, reason: id);
      }
      expect(GameRulesCatalogue.forGame('nope'), isNull);
    },
  );

  test(
    'first play: unseen shows, seen does not, no child counts as unseen',
    () {
      expect(RulesFirstPlay.shouldAutoShow(<String>{}, 'memory_match'), isTrue);
      expect(RulesFirstPlay.shouldAutoShow(null, 'memory_match'), isTrue);
      final seen = RulesFirstPlay.markSeen(<String>{}, 'memory_match');
      expect(RulesFirstPlay.shouldAutoShow(seen, 'memory_match'), isFalse);
      expect(RulesFirstPlay.shouldAutoShow(seen, 'sort_bins'), isTrue);
    },
  );
}
