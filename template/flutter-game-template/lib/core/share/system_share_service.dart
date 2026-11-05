import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'share_service.dart';

/// Android share sheet through `share_plus`. The only file that imports it.
class SystemShareService extends BaseShareService {
  SystemShareService({required this.gameName, required this.link});

  @override
  final String gameName;
  @override
  final String? link;

  @override
  Future<void> send(String text, Uint8List? image) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: image == null
            ? null
            : [XFile.fromData(image, mimeType: 'image/png', name: 'share.png')],
        fileNameOverrides: image == null ? null : ['share.png'],
      ),
    );
  }
}
