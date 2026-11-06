import 'package:url_launcher/url_launcher.dart';

import 'external_link_service.dart';

/// Opens the Play Store through `url_launcher`. The only file that imports it.
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
}
