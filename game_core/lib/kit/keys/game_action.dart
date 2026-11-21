/// What a key does in a game. Left, right, up, down, [action] and the four answer picks exist once
/// per player; [pause], [question] and [exit] are shared by both players.
enum GameAction {
  left,
  right,
  up,
  down,

  /// The main button: confirm, shoot, flip, drop.
  action,
  pick1,
  pick2,
  pick3,
  pick4,
  pause,
  question,
  exit;

  /// True for the actions both players share (they live in the slot of player 0).
  bool get shared =>
      this == GameAction.pause ||
      this == GameAction.question ||
      this == GameAction.exit;

  /// The answer number (1 to 4) of a pick action, else null.
  int? get pickNumber => switch (this) {
    GameAction.pick1 => 1,
    GameAction.pick2 => 2,
    GameAction.pick3 => 3,
    GameAction.pick4 => 4,
    _ => null,
  };

  /// Plain words for the Controls screen and screen readers.
  String get label => switch (this) {
    GameAction.left => 'Move left',
    GameAction.right => 'Move right',
    GameAction.up => 'Select or zap',
    GameAction.down => 'Best choice or slow down',
    GameAction.action => 'Action',
    GameAction.pick1 => 'Answer 1',
    GameAction.pick2 => 'Answer 2',
    GameAction.pick3 => 'Answer 3',
    GameAction.pick4 => 'Answer 4',
    GameAction.pause => 'Pause',
    GameAction.question => 'Question',
    GameAction.exit => 'Exit',
  };
}

/// One bindable place: an action for a player (1 or 2), or a shared action (player 0).
class KeySlot {
  const KeySlot(this.action, this.player);

  final GameAction action;
  final int player;

  /// Stable text id, used for saving: `p1.left`, `p2.pick3`, `all.pause`.
  String get id => '${player == 0 ? 'all' : 'p$player'}.${action.name}';

  @override
  bool operator ==(Object other) =>
      other is KeySlot && other.action == action && other.player == player;

  @override
  int get hashCode => Object.hash(action, player);

  @override
  String toString() => 'KeySlot($id)';

  /// Every slot, in the order the Controls screen lists them.
  static final List<KeySlot> all = [
    for (final a in GameAction.values)
      if (a.shared) KeySlot(a, 0) else ...[KeySlot(a, 1), KeySlot(a, 2)],
  ];

  static KeySlot? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// A key press turned into what the game should do, and for whom.
class GameInput {
  const GameInput(this.action, this.player, {this.repeat = false});

  final GameAction action;

  /// 1 or 2. Shared actions and a single-player game report player 1.
  final int player;

  /// True when the key is held down and repeating.
  final bool repeat;

  @override
  String toString() =>
      'GameInput(${action.name}, p$player${repeat ? ', repeat' : ''})';
}
