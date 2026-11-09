/// Numeric answers for `numeric` items: integers and decimals only, no fractions.
///
/// Equivalent written forms count as the same number: `0.5`, `.5`, `0.50`,
/// `1,000`, `1 000` and `1000` are all accepted. A comma is only a thousands
/// separator (groups of exactly three digits), never a decimal mark, and `1/2`
/// is not a number here (fraction answers use `mcq`).
library;

final RegExp _numberForm = RegExp(
  r'^[+-]?(?:\d{1,3}(?:[ ,]\d{3})+|\d+)?(?:\.\d*)?$',
);

/// Parses [input] as a plain number, or returns null when it is not one.
double? parseNumeric(String input) {
  var s = input
      .replaceAll('−', '-') // minus sign
      .replaceAll(RegExp(r'[   ]'), ' ') // special spaces
      .trim();
  if (s.isEmpty || !_numberForm.hasMatch(s)) return null;
  if (!RegExp(r'\d').hasMatch(s)) return null;
  s = s.replaceAll(RegExp(r'[ ,]'), '');
  if (s.startsWith('+')) s = s.substring(1);
  if (s.startsWith('.')) s = '0$s';
  if (s.startsWith('-.')) s = '-0${s.substring(1)}';
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return double.tryParse(s);
}

/// Parses a JSON value (a number or a string) as a number, or null.
double? numericFromJson(Object? value) {
  if (value is num) return value.isFinite ? value.toDouble() : null;
  if (value is String) return parseNumeric(value);
  return null;
}

/// True when two numbers are equal within [tolerance] (plus float noise).
bool numbersMatch(double a, double b, {double tolerance = 0}) {
  final scale = [a.abs(), b.abs(), 1.0].reduce((x, y) => x > y ? x : y);
  return (a - b).abs() <= tolerance + 1e-9 * scale;
}

/// Whether the player's typed [input] is a correct answer to a numeric item.
bool isNumericAnswerCorrect(
  String input,
  Object answer, {
  double tolerance = 0,
}) {
  final given = parseNumeric(input);
  final expected = numericFromJson(answer);
  if (given == null || expected == null) return false;
  return numbersMatch(given, expected, tolerance: tolerance);
}
