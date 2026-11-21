import 'package:flutter/widgets.dart';

/// WordGrid's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class WordGridIds {
  static Key mgCell(String g, int r, int c) => Key('$g.cell.$r.$c');
  static Key mgClue(String g, int i) => Key('$g.clue.$i');
  static Key mgGiveUp(String g) => Key('$g.give_up');
  static Key mgGrid(String g) => Key('$g.grid');
  static Key mgLetter(String g, int i) => Key('$g.letter.$i');
  static Key mgStartAlt(String g) => Key('$g.start_alt');
  static Key mgUndo(String g) => Key('$g.undo');
}
