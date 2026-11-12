import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'external_link_service.dart';

/// Opens the Play Store and web pages through `url_launcher`, and reads the version through
/// `package_info_plus`. The only file that imports them.
class UrlExternalLinkService implements ExternalLinkService {
  const UrlExternalLinkService();

  @override
  Future<bool> openStorePage(String packageName) async {
    final market = Uri.parse('market://details?id=$packageName');
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // No Play Store app: fall back to the web page.
    }
    try {
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '';
    }
  }
}
