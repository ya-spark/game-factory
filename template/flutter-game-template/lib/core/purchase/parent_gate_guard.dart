import 'dart:math';

import '../clock.dart';

enum GateAnswer { correct, wrong, locked }

/// Pure-Dart rules of the parent gate: a multiplication with factors 6 to 9, new numbers after
/// every wrong answer, and a lock after [maxWrong] wrong answers in a row.
/// The clock is injectable so tests can move time.
class ParentGateGuard {
  ParentGateGuard({Clock? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random() {
    newQuestion();
  }

  static const int maxWrong = 3;
  static const Duration lockDuration = Duration(seconds: 60);

  final Clock _clock;
  final Random _random;
  int a = 6;
  int b = 6;
  int _wrongInARow = 0;
  DateTime? _lockedUntil;

  bool get isLocked {
    final until = _lockedUntil;
    if (until == null) return false;
    if (_clock().isBefore(until)) return true;
    _lockedUntil = null;
    _wrongInARow = 0;
    return false;
  }

  /// Seconds left of the lock (0 when not locked).
  int get lockSecondsLeft {
    if (!isLocked) return 0;
    return (_lockedUntil!.difference(_clock()).inMilliseconds / 1000).ceil();
  }

  void newQuestion() {
    a = 6 + _random.nextInt(4);
    b = 6 + _random.nextInt(4);
  }

  String get question => '$a x $b';

  GateAnswer submit(String text) {
    if (isLocked) return GateAnswer.locked;
    if (int.tryParse(text.trim()) == a * b) {
      _wrongInARow = 0;
      newQuestion();
      return GateAnswer.correct;
    }
    _wrongInARow++;
    newQuestion();
    if (_wrongInARow >= maxWrong) {
      _lockedUntil = _clock().add(lockDuration);
      return GateAnswer.locked;
    }
    return GateAnswer.wrong;
  }
}
