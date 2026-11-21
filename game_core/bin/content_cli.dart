// `dart run game_core:content_cli COMMAND [options]` (run from the app or content project root).
import 'dart:io';

import 'package:game_core/cli/content_cli.dart';

Future<void> main(List<String> args) async {
  exit(await runCli(args, env: Platform.environment, out: stdout, err: stderr));
}
