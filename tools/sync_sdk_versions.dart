import 'dart:io';

import 'src/sdk_version_sync.dart';

Future<void> main(List<String> arguments) async {
  final scriptFile = File(Platform.script.toFilePath()).absolute;
  final result = await runSdkVersionSync(
    arguments: arguments,
    rootDirectory: scriptFile.parent.parent,
    standardOut: stdout,
    standardError: stderr,
  );
  exitCode = result;
}
