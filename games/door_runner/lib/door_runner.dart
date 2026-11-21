/// Door runner: the runner stands in a lane and the doors come down, each carrying an answer.
/// Steer, zap, slow down, pause. A container lists [doorRunnerGame] in its registry and provides
/// a `GameHost` (speech, banners, settings) above it. Spec: `docs/SPEC.md`.
library;

export 'src/door_runner_ids.dart';
export 'src/door_runner_screen.dart';
export 'src/rules/door_runner_rules.dart' show doorRunnerId;
