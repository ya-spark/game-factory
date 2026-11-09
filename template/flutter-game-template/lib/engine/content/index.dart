/// Content index: lists every pack file of one app with its sha256 and size,
/// and an Ed25519 signature over the exact index bytes. Pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import 'models.dart';

const int indexFormat = 1;

String sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

Map<String, dynamic> _fileEntry(String path, List<int> bytes) => {
  'path': path,
  'sha256': sha256Hex(bytes),
  'size': bytes.length,
};

/// Builds the index for one app.
///
/// [packFiles] maps each pack file path (as served, for example
/// `packs/maths_y3_add.json`) to its bytes. [readAsset] returns the bytes of an
/// asset path used by a pack, or null when it is missing. Output is
/// deterministic: no timestamps, sorted by pack id.
Map<String, dynamic> buildIndex({
  required String app,
  required int version,
  required Map<String, Uint8List> packFiles,
  required Uint8List? Function(String assetPath) readAsset,
}) {
  final packs = <Map<String, dynamic>>[];
  for (final e in packFiles.entries) {
    final pack = ContentPack(
      jsonDecode(utf8.decode(e.value)) as Map<String, dynamic>,
    );
    final assets = <String>{};
    for (final it in pack.items) {
      for (final a in [it.image, it.audio]) {
        if (a != null) assets.add(a);
      }
    }
    packs.add({
      'id': pack.id,
      'version': pack.version,
      'subject': pack.subject,
      'year': pack.year,
      'topic': pack.topic,
      'title': pack.title,
      'product_id': pack.productId,
      'items': pack.items.length,
      'file': _fileEntry(e.key, e.value),
      'assets': [
        for (final a in assets.toList()..sort())
          _fileEntry(
            a,
            readAsset(a) ??
                (throw StateError('asset "$a" of pack ${pack.id} is missing')),
          ),
      ],
    });
  }
  packs.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  return {
    'format': indexFormat,
    'app': app,
    'lang': contentLang,
    'version': version,
    'packs': packs,
  };
}

/// The exact bytes that are hashed and signed.
Uint8List encodeIndex(Map<String, dynamic> index) => Uint8List.fromList(
  utf8.encode('${const JsonEncoder.withIndent('  ').convert(index)}\n'),
);

/// Reads a signing key file: base64 of the 32-byte Ed25519 seed. Blank lines
/// and lines starting with `#` are ignored.
List<int> parseSigningKey(String fileText) {
  final line = fileText
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
  final bytes = base64.decode(line);
  if (bytes.length != 32) {
    throw const FormatException('signing key must be a base64 32-byte seed');
  }
  return bytes;
}

final Ed25519 _ed = Ed25519();

/// Signs [indexBytes]; returns the signature as base64.
Future<String> signIndex(Uint8List indexBytes, List<int> seed) async {
  final pair = await _ed.newKeyPairFromSeed(seed);
  final sig = await _ed.sign(indexBytes, keyPair: pair);
  return base64.encode(sig.bytes);
}

/// The public key (base64) for a seed, to hand to the app.
Future<String> publicKeyOf(List<int> seed) async {
  final pair = await _ed.newKeyPairFromSeed(seed);
  return base64.encode((await pair.extractPublicKey()).bytes);
}

/// Checks a base64 signature of [indexBytes] against a base64 public key.
Future<bool> verifyIndex(
  Uint8List indexBytes,
  String signatureB64,
  String publicKeyB64,
) async {
  try {
    final sig = Signature(
      base64.decode(signatureB64.trim()),
      publicKey: SimplePublicKey(
        base64.decode(publicKeyB64.trim()),
        type: KeyPairType.ed25519,
      ),
    );
    return await _ed.verify(indexBytes, signature: sig);
  } on FormatException {
    return false;
  }
}
