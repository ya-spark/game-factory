/// What the Door runner UI components draw. Plain data: the rules (pure Dart) fill it in,
/// the widgets never decide anything.
library;

enum DoorMark { idle, wrong, right }

class DoorView {
  const DoorView(this.label, {this.mark = DoorMark.idle});
  final String label;
  final DoorMark mark;
}

class DoorRunnerView {
  const DoorRunnerView({
    required this.question,
    required this.doors,
    required this.lane,
    this.approach = 0,
    this.hearts,
    this.maxHearts = 3,
    this.score = 0,
    this.streak,
    this.paused = false,
    this.answered = false,
    this.world = 0,
    this.speed = 1,
  });

  final String question;
  final List<DoorView> doors;

  /// The runner's lane, 0 to doors.length - 1.
  final int lane;

  /// How far the doors have come, 0 (top) to 1 (at the runner line).
  final double approach;

  /// Hearts left; null at the younger level (no hearts shown).
  final int? hearts;
  final int maxHearts;
  final int score;

  /// Streak shown in the top strip; null at the younger level.
  final int? streak;
  final bool paused;
  final bool answered;

  /// Which look the scene has (0 dusk, 1 aurora, 2 ember); changes as the run goes on, like
  /// Wingy's palettes.
  final int world;

  /// 1 normally, 0.4 while Down is held; drives the floor scroll and the runner's stride.
  final double speed;

  DoorRunnerView copyWith({
    int? lane,
    double? approach,
    bool? paused,
    List<DoorView>? doors,
    double? speed,
    int? world,
  }) => DoorRunnerView(
    question: question,
    doors: doors ?? this.doors,
    lane: lane ?? this.lane,
    approach: approach ?? this.approach,
    hearts: hearts,
    maxHearts: maxHearts,
    score: score,
    streak: streak,
    paused: paused ?? this.paused,
    answered: answered,
    world: world ?? this.world,
    speed: speed ?? this.speed,
  );
}
