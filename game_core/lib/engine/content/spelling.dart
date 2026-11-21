/// Australian-spelling check: a word list of common US spellings.
/// Findings are warnings only; the author decides.
library;

/// US stem to Australian stem. Suffixes (s, ed, ing, er, ation ...) are matched
/// automatically, so `organiz` catches organize, organized and organization.
const Map<String, String> usToAuSpelling = {
  'color': 'colour',
  'favorite': 'favourite',
  'neighbor': 'neighbour',
  'behavior': 'behaviour',
  'honor': 'honour',
  'humor': 'humour',
  'labor': 'labour',
  'flavor': 'flavour',
  'harbor': 'harbour',
  'organiz': 'organis',
  'recogniz': 'recognis',
  'realiz': 'realis',
  'apologiz': 'apologis',
  'criticiz': 'criticis',
  'summariz': 'summaris',
  'categoriz': 'categoris',
  'memoriz': 'memoris',
  'analyz': 'analys',
  'center': 'centre',
  'theater': 'theatre',
  'meter': 'metre',
  'liter': 'litre',
  'fiber': 'fibre',
  'gray': 'grey',
  'defense': 'defence',
  'offense': 'offence',
  'catalog': 'catalogue',
  'dialog': 'dialogue',
  'jewelry': 'jewellery',
  'aluminum': 'aluminium',
  'pajamas': 'pyjamas',
  'cozy': 'cosy',
  'traveler': 'traveller',
  'traveling': 'travelling',
  'modeling': 'modelling',
  'cancelation': 'cancellation',
};

/// A US spelling [found] in text, with the Australian form [suggest].
class SpellingHit {
  const SpellingHit(this.found, this.suggest);
  final String found;
  final String suggest;
}

final List<MapEntry<RegExp, String>> _patterns = [
  for (final e in usToAuSpelling.entries)
    MapEntry(
      RegExp(
        '\\b${e.key}(?:e|es|ed|ing|er|ers|ation|ations|s|ful|ly|y)?\\b',
        caseSensitive: false,
      ),
      e.value,
    ),
  // "math" alone is the US form; "maths" is correct.
  MapEntry(RegExp(r'\bmath\b', caseSensitive: false), 'maths'),
  MapEntry(RegExp(r'\bmom\b', caseSensitive: false), 'mum'),
];

/// Finds US spellings in [text].
List<SpellingHit> findUsSpellings(String text) {
  final hits = <SpellingHit>[];
  for (final p in _patterns) {
    for (final m in p.key.allMatches(text)) {
      hits.add(SpellingHit(m.group(0)!, p.value));
    }
  }
  return hits;
}
