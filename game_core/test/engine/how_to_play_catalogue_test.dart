import 'package:game_core/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every entry has 1 to 3 rules and 2 or 3 tips, and no duplicate ids',
    () {
      final ids = <String>{};
      for (final g in HowToPlayCatalogue.all) {
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
        shooterId,
        'door_runner',
        tugOfWarId,
        flashReviewId,
      ]) {
        expect(HowToPlayCatalogue.forGame(id), isNotNull, reason: id);
      }
      expect(HowToPlayCatalogue.forGame('nope'), isNull);
    },
  );

  test(
    'first play: unseen shows, seen does not, no child counts as unseen',
    () {
      expect(
        HowToPlayFirstPlay.shouldAutoShow(<String>{}, 'memory_match'),
        isTrue,
      );
      expect(HowToPlayFirstPlay.shouldAutoShow(null, 'memory_match'), isTrue);
      final seen = HowToPlayFirstPlay.markSeen(<String>{}, 'memory_match');
      expect(HowToPlayFirstPlay.shouldAutoShow(seen, 'memory_match'), isFalse);
      expect(HowToPlayFirstPlay.shouldAutoShow(seen, 'sort_bins'), isTrue);
    },
  );
}
