/// Opens other apps' pages outside the game, and reads the app's own version. Game and UI code
/// depend on this interface only.
abstract class ExternalLinkService {
  /// Opens the Play Store page of [packageName] (the Play Store app, else the web page).
  /// Returns false when nothing could be opened.
  Future<bool> openStorePage(String packageName);

  /// Opens a web page (the privacy policy) in the browser. Returns false when it could not open.
  Future<bool> openUrl(String url);

  /// The version name of the installed app, for example `1.0.3`; empty when unknown.
  Future<String> appVersion();
}

/// Records the opened packages and urls (tests).
class FakeExternalLinkService implements ExternalLinkService {
  final List<String> opened = [];
  final List<String> openedUrls = [];
  String version = '1.2.3';

  @override
  Future<bool> openStorePage(String packageName) async {
    opened.add(packageName);
    return true;
  }

  @override
  Future<bool> openUrl(String url) async {
    openedUrls.add(url);
    return true;
  }

  @override
  Future<String> appVersion() async => version;
}
