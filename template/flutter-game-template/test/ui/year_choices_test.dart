import 'package:flutter_game_template/ui/year_choices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown or empty content years fall back to Foundation to Year 10', () {
    final all = [for (var y = 0; y <= 10; y++) y];
    expect(yearChoices(null), all);
    expect(yearChoices(const []), all);
  });

  test(
    'the years the content covers are offered, including Year 11 and 12',
    () {
      expect(yearChoices(const [7, 8, 9, 10, 11, 12]), [7, 8, 9, 10, 11, 12]);
      expect(yearChoices(const [0, 1, 2]), [0, 1, 2]);
    },
  );

  test('the player year is always listed, in order', () {
    expect(yearChoices(const [11, 12], current: 10), [10, 11, 12]);
    expect(yearChoices(const [11, 12], current: 12), [11, 12]);
  });
}
