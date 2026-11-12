/// The year levels to offer (0 = Foundation), lowest first. [contentYears] are the years the
/// app's content covers; Foundation to Year 10 when unknown or empty. [current] (a player's own
/// year) is always listed so a dropdown never holds a value that is not an item.
/// Shared by the New player picker and the grown-ups' year switch.
List<int> yearChoices(List<int>? contentYears, {int? current}) {
  final base = contentYears == null || contentYears.isEmpty
      ? [for (var y = 0; y <= 10; y++) y]
      : contentYears;
  return ({...base, ?current}.toList()..sort());
}
