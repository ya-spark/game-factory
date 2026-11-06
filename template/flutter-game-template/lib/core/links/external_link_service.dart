/// Opens other apps' pages outside the game. Game and UI code depend on this interface only.
abstract class ExternalLinkService {
  /// Opens the Play Store page of [packageName] (the Play Store app, else the web page).
  /// Returns false when nothing could be opened.
  Future<bool> openStorePage(String packageName);
}

/// Records the opened packages (tests).
class FakeExternalLinkService implements ExternalLinkService {
  final List<String> opened = [];

  @override
  Future<bool> openStorePage(String packageName) async {
    opened.add(packageName);
    return true;
  }
}
