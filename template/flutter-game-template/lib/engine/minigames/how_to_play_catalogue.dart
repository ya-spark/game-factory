/// How-to-play text for every Craft minigame and the first-play rule (R1a). Pure Dart.
///
/// The text is written once, here, and is kept word for word in each app's `docs/SPEC.md`
/// ("How to play"). Calm, plain wording; no pressure and no people.
library;

/// Rules (1 to 3 short lines) and tips (2 or 3) of one game.
class HowToPlay {
  const HowToPlay(this.id, this.title, this.rules, this.tips);
  final String id;
  final String title;
  final List<String> rules;
  final List<String> tips;
}

abstract final class HowToPlayCatalogue {
  static HowToPlay? forGame(String id) => _byId[id];

  static List<HowToPlay> get all => _all;

  /// The ids with an entry.
  static Set<String> get ids => _byId.keys.toSet();

  static final Map<String, HowToPlay> _byId = {for (final g in _all) g.id: g};

  static const List<HowToPlay> _all = [
    HowToPlay(
      'quick_quiz',
      'Quick quiz',
      [
        'Answer the questions one by one.',
        'Pick a topic to practise one thing, or play a mixed round.',
        'After each answer you see whether it was right, and often why.',
      ],
      [
        'Take your time. There is no rush to answer.',
        'Read every answer before you choose.',
        'Play the same topic again to get better at it.',
      ],
    ),
    HowToPlay(
      'memory_match',
      'Memory match',
      [
        'Flip two cards at a time to find the matching pairs. Each pair is a question and its answer.',
        'Match every pair to finish the board.',
      ],
      [
        'Try to remember where each card is.',
        'Younger levels have no timer. Older levels add a gentle clock.',
      ],
    ),
    HowToPlay(
      'sort_bins',
      'Sort into bins',
      [
        'Put each item into the right bin. Drag it there, or tap the item and then the bin.',
        'A wrong drop never ends the round. The item stays and you try again.',
      ],
      [
        'Read the names of the bins first.',
        'Take your time. Every item gets as many tries as it needs.',
      ],
    ),
    HowToPlay(
      'series_builder',
      'Series builder',
      [
        'Put the steps in the right order by tapping the tiles one after the other.',
        'A wrong tile is greyed out and you try again.',
      ],
      [
        'Find the first step before you start tapping.',
        'Older levels add a gentle timer.',
      ],
    ),
    HowToPlay(
      'word_builder',
      'Word builder',
      [
        'Build the answer from the letter tiles. Use the hint if you need it.',
        'After a miss, the correct spelling is shown.',
      ],
      [
        'Say the word to yourself as you build it.',
        'Older levels build the word and press Check.',
      ],
    ),
    HowToPlay(
      'true_false',
      'True or false',
      [
        'Read each statement, then choose True or False.',
        'After each answer you often see why.',
      ],
      [
        'Read the whole statement before you answer.',
        'Look for words like always, never and only.',
      ],
    ),
    HowToPlay(
      'cloze_fix',
      'Cloze and grammar fix',
      ['Choose the word that fills the gap, or the corrected sentence.'],
      [
        'Read the sentence out loud in your head with each choice.',
        'Check the whole sentence, not just the gap.',
      ],
    ),
    HowToPlay(
      'equation_builder',
      'Equation builder',
      [
        'Build a sum from the tiles so that it equals the target number.',
        'Any sum that works is a right answer.',
      ],
      [
        'Start with the biggest tile that fits.',
        'Try different tiles if you get stuck.',
      ],
    ),
    HowToPlay(
      'word_grid',
      'Word search and crossword',
      [
        'Choose word search or crossword on the start screen.',
        'Find the words in the grid, or fill in the crossword from the clues.',
      ],
      ['Start with the words you know best.', 'There is no need to hurry.'],
    ),
    HowToPlay(
      'shooter',
      'Shooter',
      [
        'Read the question, then tap the target with the right answer to shoot it.',
        'Targets sway from side to side. Younger levels have no timer and let you try another target.',
      ],
      [
        'Read every target before you shoot.',
        'Take a moment if the question is tricky.',
      ],
    ),
    HowToPlay(
      'balloon_pop',
      'Balloon pop',
      [
        'Read the question, then pop the balloon with the right answer.',
        'Balloons float up the screen. Younger levels have no timer.',
      ],
      [
        'Read every balloon before you pop one.',
        'Take a moment if the question is tricky.',
      ],
    ),
    HowToPlay(
      'door_runner',
      'Door runner',
      [
        'Read the question, then run through the door with the right answer.',
        'Younger levels let you try another door after a wrong one.',
      ],
      [
        'Read every door before you choose.',
        'Take a moment if the question is tricky.',
      ],
    ),
    HowToPlay(
      'tug_of_war',
      'Tug of war',
      [
        'Answer a question. A right answer pulls the rope towards you; a wrong or slow one lets it slip back.',
        'Bring the rope all the way to your end to win the round.',
        'If you see Play with a sibling, two players can take turns on one device, each with their own questions.',
      ],
      [
        'Read every answer before you choose.',
        'On the youngest level a wrong answer never pulls the rope back.',
        'Take a breath between questions. A wrong answer is just a chance to learn.',
      ],
    ),
    HowToPlay(
      'flash_review',
      'Flash review',
      [
        'Look at the card, then flip it to see the answer.',
        'Tap "I knew it" or "Not yet". Cards you miss come back to practise later.',
      ],
      [
        'Try to answer in your head before you flip.',
        'Be honest. "Not yet" just means more practice.',
      ],
    ),
  ];
}

/// The first-play rule: the dialog opens by itself the first time a child opens a game.
abstract final class HowToPlayFirstPlay {
  /// True when the dialog should open by itself. With no child ([seen] null) nothing is
  /// stored, so the game counts as unseen.
  static bool shouldAutoShow(Set<String>? seen, String gameId) =>
      seen == null || !seen.contains(gameId);

  /// The seen set after the child closed the dialog for [gameId].
  static Set<String> markSeen(Set<String> seen, String gameId) => {
    ...seen,
    gameId,
  };
}
