/// AI tutor hook (issue 1C1). Off by default; no AI feature ships and there is no vendor code.
library;

abstract interface class AiTutorService {
  /// False in every shipped build (`ai.enabled: false`).
  bool get isAvailable;

  /// Explains an item in words for a child. Only called when [isAvailable].
  Future<String> explain(String itemId, {String? question});
}

/// The only implementation that ships: nothing is available, nothing is sent anywhere.
class NoAiTutorService implements AiTutorService {
  const NoAiTutorService();

  @override
  bool get isAvailable => false;

  @override
  Future<String> explain(String itemId, {String? question}) async =>
      throw UnsupportedError('The AI tutor is off');
}
