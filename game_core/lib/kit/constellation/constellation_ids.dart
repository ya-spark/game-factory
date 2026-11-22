import 'package:flutter/widgets.dart';

/// Stable test IDs of the Constellation trail (hard rule 4).
abstract final class ConstellationIds {
  static const root = Key('constellation.root');
  static String topic(String topicKey) => 'constellation.topic.$topicKey';
  static Key topicKeyOf(String topicKey) => Key(topic(topicKey));
  static Key star(String skillKey) => Key('constellation.star.$skillKey');
}
