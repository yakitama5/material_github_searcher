import 'dart:io';

import 'src/package_dependency_checker.dart';

Future<void> main() async {
  final scriptFile = File(Platform.script.toFilePath()).absolute;
  final result = runPackageDependencyCheck(
    rootDirectory: scriptFile.parent.parent,
    standardOut: stdout,
    standardError: stderr,
  );
  exitCode = result;
}
