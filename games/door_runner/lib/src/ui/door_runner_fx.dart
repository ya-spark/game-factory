import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Effects the screen asks for: a floating "+N", a sparkle burst on a door, a screen shake.
/// The field draws and ages them; nothing here touches the rules.
class DoorRunnerFx extends ChangeNotifier {
  final List<FxText> texts = [];
  final List<FxBurst> bursts = [];
  double shake = 0;

  void floatText(String text, int lane, Color color) {
    texts.add(FxText(text, lane, color));
    notifyListeners();
  }

  void burst(int lane, Color color) {
    bursts.add(FxBurst(lane, color));
    notifyListeners();
  }

  void shakeScreen() {
    shake = 0.25;
    notifyListeners();
  }

  /// Called every frame by the field.
  void age(double dt) {
    for (final t in texts) {
      t.age += dt;
    }
    for (final b in bursts) {
      b.age += dt;
    }
    texts.removeWhere((t) => t.age >= FxText.life);
    bursts.removeWhere((b) => b.age >= FxBurst.life);
    if (shake > 0) shake = (shake - dt).clamp(0, 1).toDouble();
  }
}

class FxText {
  FxText(this.text, this.lane, this.color);
  final String text;
  final int lane;
  final Color color;
  double age = 0;
  static const life = 0.9;
}

class FxBurst {
  FxBurst(this.lane, this.color);
  final int lane;
  final Color color;
  double age = 0;
  static const life = 0.5;
}
