import 'dart:typed_data';

/// Sharing through the system share sheet. The app sends nothing itself: the player picks
/// the target app. Game and UI code depend on this interface only.
abstract class ShareService {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});

  Future<void> shareAchievement({required String title, Uint8List? image});

  /// Invites to the game with the high score message. Does nothing while there is no link.
  Future<void> shareApp({int bestScore = 0});

  /// True when share texts carry a link; "Share app" is shown only then.
  bool get hasLink;
}

/// Builds the texts and delegates the actual sending to [send].
abstract class BaseShareService implements ShareService {
  String get gameName;

  /// The link added on a new line after the message, or null for none.
  String? get link;

  @override
  bool get hasLink => link != null && link!.isNotEmpty;

  String _withLink(String text) => hasLink ? '$text\n$link' : text;

  String scoreText(int score) =>
      _withLink('This is my high score in $gameName: $score. Can you beat it?');

  String achievementText(String title) =>
      _withLink('I unlocked "$title" in $gameName! Can you beat it?');

  String appText(int bestScore) =>
      bestScore > 0 ? scoreText(bestScore) : _withLink('Try $gameName!');

  Future<void> send(String text, Uint8List? image);

  @override
  Future<void> shareScore({required int score, Uint8List? image}) =>
      send(scoreText(score), image);

  @override
  Future<void> shareAchievement({required String title, Uint8List? image}) =>
      send(achievementText(title), image);

  @override
  Future<void> shareApp({int bestScore = 0}) async {
    if (!hasLink) return;
    await send(appText(bestScore), null);
  }
}

/// Records what would be shared (tests).
class FakeShareService extends BaseShareService {
  FakeShareService({this.gameName = 'Test Game', this.link});

  @override
  final String gameName;
  @override
  final String? link;

  final List<({String text, Uint8List? image})> sent = [];

  @override
  Future<void> send(String text, Uint8List? image) async =>
      sent.add((text: text, image: image));
}
