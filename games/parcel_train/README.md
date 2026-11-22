# game_parcel_train

Parcel train (was Snake): a toy train picks up parcels on a play mat. Five courses with a station, a golden parcel and three bumpers, and Free ride (the old endless game). Lives once in `game-factory/games/` (SH1, owner 2026-11-21); containers list it.

- Spec: `docs/SPEC.md` (the only copy, with a test map). Public API: `lib/parcel_train.dart` (`ParcelTrainScreen`, `TrainGame`, `trainCourses`, `trainStarScores`, `ParcelTrainIds`).
- Needs Flutter and `game_core` (shared kit and host contract). A container adds `game_parcel_train` as a git dependency at one commit of `game-factory`, pins `game_core` with `dependency_overrides` to the same commit, and provides a `GameHost` (`GameHostScope`) above the game.
- Owner rule 2026-11-22: no living beings; the folder, package and id are the title.
