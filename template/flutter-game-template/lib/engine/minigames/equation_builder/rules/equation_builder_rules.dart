/// Equation builder rules: build an expression from number and operator tiles that equals the
/// target (the `numeric` item's answer). Any valid expression counts, not only the one the
/// game made the tiles from. Pure Dart, random is injected.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../../content/numeric.dart';
import '../../minigame_level.dart';

const String equationBuilderId = 'equation_builder';

const String opAdd = '+';
const String opSub = '−';
const String opMul = '×';
const String opDiv = '÷';

bool isOperator(String t) =>
    t == opAdd || t == opSub || t == opMul || t == opDiv;

class EquationSettings {
  const EquationSettings({
    required this.operators,
    required this.extraNumbers,
    required this.extraOperators,
    required this.secondsPerQuestion,
  });

  /// Operators the game builds its own solution from.
  final List<String> operators;
  final int extraNumbers;
  final int extraOperators;

  /// 0 means no timer.
  final int secondsPerQuestion;

  factory EquationSettings.forLevel(MiniGameLevel l) => !l.older
      ? const EquationSettings(
          operators: [opAdd, opSub],
          extraNumbers: 1,
          extraOperators: 0,
          secondsPerQuestion: 0,
        )
      : EquationSettings(
          operators: l.harder
              ? const [opAdd, opSub, opMul, opDiv]
              : const [opAdd, opSub, opMul],
          extraNumbers: l.harder ? 3 : 2,
          extraOperators: 1,
          secondsPerQuestion: l.harder ? 40 : 60,
        );
}

/// Evaluates number and operator tokens with the usual order (× and ÷ before + and −).
/// Null when the tokens are not a well formed expression or divide by zero.
double? evaluateTokens(List<String> tokens) {
  if (tokens.isEmpty || tokens.length.isEven) return null;
  final nums = <double>[];
  final ops = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    if (i.isEven) {
      final n = parseNumeric(tokens[i]);
      if (n == null) return null;
      nums.add(n);
    } else {
      if (!isOperator(tokens[i])) return null;
      ops.add(tokens[i]);
    }
  }
  // First pass: × and ÷.
  final n2 = <double>[nums.first];
  final o2 = <String>[];
  for (var i = 0; i < ops.length; i++) {
    final b = nums[i + 1];
    if (ops[i] == opMul) {
      n2[n2.length - 1] = n2.last * b;
    } else if (ops[i] == opDiv) {
      if (b == 0) return null;
      n2[n2.length - 1] = n2.last / b;
    } else {
      o2.add(ops[i]);
      n2.add(b);
    }
  }
  var r = n2.first;
  for (var i = 0; i < o2.length; i++) {
    r = o2[i] == opAdd ? r + n2[i + 1] : r - n2[i + 1];
  }
  return r;
}

/// True when the tokens form a valid expression equal to [target].
bool equationHitsTarget(List<String> tokens, num target) {
  final v = evaluateTokens(tokens);
  return v != null && numbersMatch(v, target.toDouble());
}

class EquationPuzzle {
  const EquationPuzzle({
    required this.target,
    required this.tiles,
    required this.solution,
  });
  final int target;

  /// Shuffled tiles the child can use, each once.
  final List<String> tiles;

  /// One expression the game knows is right (shown when the child does not find one).
  final List<String> solution;

  String get solutionText => '${solution.join(' ')} = $target';
}

/// The target of a `numeric` item when it is a whole number from 0 to 999, else null.
int? equationTarget(ContentItem item) {
  if (item.type != ItemType.numeric) return null;
  final v = numericFromJson(item.json['answer']);
  if (v == null || v != v.roundToDouble() || v < 0 || v > 999) return null;
  return v.toInt();
}

/// Builds the tiles for one item: a known solution plus distractor tiles.
EquationPuzzle? buildEquation(
  ContentItem item,
  EquationSettings s,
  Random random,
) {
  final t = equationTarget(item);
  if (t == null) return null;
  final options = <List<String>>[];
  for (final op in s.operators) {
    switch (op) {
      case opAdd:
        if (t >= 2) {
          final a = 1 + random.nextInt(t - 1);
          options.add(['$a', opAdd, '${t - a}']);
        }
      case opSub:
        final b = 1 + random.nextInt(9);
        options.add(['${t + b}', opSub, '$b']);
      case opMul:
        final ds = [
          for (var d = 2; d < t; d++)
            if (t % d == 0) d,
        ];
        if (ds.isNotEmpty) {
          final d = ds[random.nextInt(ds.length)];
          options.add(['$d', opMul, '${t ~/ d}']);
        }
      case opDiv:
        final b = 2 + random.nextInt(8);
        options.add(['${t * b}', opDiv, '$b']);
    }
  }
  if (options.isEmpty) options.add(['${t + 1}', opSub, '1']);
  final solution = options[random.nextInt(options.length)];
  final tiles = [...solution];
  final maxNum = max(9, t);
  for (var i = 0; i < s.extraNumbers; i++) {
    tiles.add('${1 + random.nextInt(maxNum)}');
  }
  final spare = [
    for (final o in [opAdd, opSub, opMul, opDiv])
      if (!tiles.contains(o)) o,
  ]..shuffle(random);
  tiles.addAll(spare.take(s.extraOperators));
  tiles.shuffle(random);
  return EquationPuzzle(target: t, tiles: tiles, solution: solution);
}

/// Screen-reader wording for a tile.
String spokenTile(String tile) => switch (tile) {
  opAdd => 'plus',
  opSub => 'minus',
  opMul => 'times',
  opDiv => 'divided by',
  _ => tile,
};
