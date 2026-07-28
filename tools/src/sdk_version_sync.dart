import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Process invocation used by the SDK version synchronizer.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
    );

final RegExp _semanticVersionPattern = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
);
final RegExp _topLevelKeyPattern = RegExp(
  r'^([a-zA-Z_][a-zA-Z0-9_-]*):(?:\s*(.*))?$',
);
final RegExp _environmentValuePattern = RegExp(
  r'^(  )(sdk|flutter):(\s*)([^#]*?)(\s+#.*)?$',
);
final RegExp _workspaceEntryPattern = RegExp(r'^  - (.+?)\s*$');
final RegExp _dependencyEntryPattern = RegExp(
  r'^  ([a-zA-Z0-9_]+):\s*(.*)$',
);
final RegExp _dependencyPropertyPattern = RegExp(
  r'^    ([a-zA-Z0-9_]+):\s*(\S+)\s*$',
);

/// Runs the SDK version synchronizer command and returns its process exit code.
Future<int> runSdkVersionSync({
  required List<String> arguments,
  required Directory rootDirectory,
  required StringSink standardOut,
  required StringSink standardError,
  ProcessRunner processRunner = _runProcess,
}) async {
  final checkOnly = switch (arguments) {
    [] => false,
    ['--check'] => true,
    _ => null,
  };

  if (checkOnly == null) {
    standardError.writeln(
      'Usage: dart tools/sync_sdk_versions.dart [--check]',
    );
    return 64;
  }

  try {
    final synchronizer = SdkVersionSynchronizer(
      rootDirectory: rootDirectory,
      processRunner: processRunner,
    );
    final result = await synchronizer.synchronize(checkOnly: checkOnly);

    if (result.changes.isEmpty) {
      standardOut.writeln('SDK constraints are already synchronized.');
      return 0;
    }

    for (final change in result.changes) {
      standardOut.writeln(
        '${change.relativePath}: ${change.before} -> ${change.after}',
      );
    }

    if (checkOnly) {
      standardError.writeln(
        'SDK constraints are out of sync. Run '
        '`mise exec -- dart tools/sync_sdk_versions.dart`.',
      );
      return 1;
    }

    standardOut.writeln('SDK constraints were synchronized.');
    return 0;
  } on SdkVersionSyncException catch (error) {
    standardError.writeln('SDK version sync failed: ${error.message}');
    return 2;
  } on Object catch (error) {
    standardError.writeln('SDK version sync failed: $error');
    return 2;
  }
}

/// Synchronizes exact Dart and Flutter constraints across a Pub Workspace.
final class SdkVersionSynchronizer {
  /// Creates a synchronizer rooted at [rootDirectory].
  const SdkVersionSynchronizer({
    required this.rootDirectory,
    this.processRunner = _runProcess,
  });

  /// Repository root that contains `mise.toml` and the root `pubspec.yaml`.
  final Directory rootDirectory;

  /// Process runner used to inspect the active Flutter SDK.
  final ProcessRunner processRunner;

  /// Validates every target and synchronizes constraints when [checkOnly] is
  /// false.
  Future<SdkVersionSyncResult> synchronize({required bool checkOnly}) async {
    final canonicalRoot = _resolveRoot(rootDirectory);
    final miseFile = File(
      '${canonicalRoot.path}${Platform.pathSeparator}mise.toml',
    );
    final rootPubspec = _validatedPubspecFile(
      canonicalRoot: canonicalRoot,
      candidate: File(
        '${canonicalRoot.path}${Platform.pathSeparator}pubspec.yaml',
      ),
      label: 'Root pubspec.yaml',
    );

    final expectedFlutter = _readMiseFlutterVersion(miseFile);
    final activeSdk = await _readActiveSdk(processRunner);
    if (activeSdk.flutter != expectedFlutter) {
      throw SdkVersionSyncException(
        'mise.toml requires Flutter $expectedFlutter, but the active Flutter '
        'is '
        '${activeSdk.flutter}. Run `mise install` and invoke this tool through '
        '`mise exec`.',
      );
    }

    final rootDocument = _PubspecDocument.read(rootPubspec);
    final memberFiles = _resolveWorkspaceMembers(
      canonicalRoot: canonicalRoot,
      rootDocument: rootDocument,
    );
    final documents = <_PubspecDocument>[
      rootDocument,
      for (final file in memberFiles) _PubspecDocument.read(file),
    ];

    final pending = <_PendingWrite>[];
    final changes = <SdkConstraintChange>[];
    for (final document in documents) {
      final update = document.withSdkVersions(
        dartVersion: activeSdk.dart,
        flutterVersion: expectedFlutter,
      );
      if (update.content == document.content) {
        continue;
      }
      pending.add(
        _PendingWrite(
          file: document.file,
          originalContent: document.content,
          updatedContent: update.content,
        ),
      );
      changes.addAll(
        update.changes.map(
          (change) => SdkConstraintChange(
            relativePath: _relativePath(canonicalRoot, document.file),
            before: change.before,
            after: change.after,
          ),
        ),
      );
    }

    if (!checkOnly && pending.isNotEmpty) {
      _replaceFiles(pending);
    }

    return SdkVersionSyncResult(changes: List.unmodifiable(changes));
  }
}

/// Result of validating or synchronizing SDK constraints.
final class SdkVersionSyncResult {
  /// Creates a result containing all detected [changes].
  const SdkVersionSyncResult({required this.changes});

  /// Constraints that differ from the versions selected by mise.
  final List<SdkConstraintChange> changes;
}

/// One constraint changed or detected by the synchronizer.
final class SdkConstraintChange {
  /// Creates a description of a constraint change.
  const SdkConstraintChange({
    required this.relativePath,
    required this.before,
    required this.after,
  });

  /// Pubspec path relative to the repository root.
  final String relativePath;

  /// Previous constraint, or `(missing)` when a key is added.
  final String before;

  /// Expected constraint, or `(removed)` when a stale key is removed.
  final String after;
}

/// A validation or synchronization failure that is safe to show to users.
final class SdkVersionSyncException implements Exception {
  /// Creates an exception with a user-facing [message].
  const SdkVersionSyncException(this.message);

  /// Description of the invalid configuration or failed operation.
  final String message;
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments,
) => Process.run(executable, arguments);

Directory _resolveRoot(Directory rootDirectory) {
  try {
    return Directory(rootDirectory.resolveSymbolicLinksSync());
  } on FileSystemException catch (error) {
    throw SdkVersionSyncException(
      'Cannot resolve repository root `${rootDirectory.path}`: '
      '${error.message}',
    );
  }
}

String _readMiseFlutterVersion(File miseFile) {
  if (!miseFile.existsSync()) {
    throw SdkVersionSyncException('`${miseFile.path}` does not exist.');
  }

  String? section;
  String? flutterVersion;
  var toolsSectionCount = 0;
  final lines = _splitLines(miseFile.readAsStringSync()).lines;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final sectionDeclaration = trimmed.split('#').first.trim();
    if (sectionDeclaration.startsWith('[') &&
        sectionDeclaration.endsWith(']')) {
      section = sectionDeclaration.substring(1, sectionDeclaration.length - 1);
      if (section == 'tools') {
        toolsSectionCount++;
        if (toolsSectionCount > 1) {
          throw const SdkVersionSyncException(
            '`mise.toml` contains duplicate [tools] sections.',
          );
        }
      }
      continue;
    }
    if (section != 'tools') {
      continue;
    }
    final assignment = RegExp(
      r'^\s*flutter\s*=\s*([^\s#]+)\s*(?:#.*)?$',
    ).firstMatch(line);
    if (assignment == null) {
      if (!RegExp(r'^\s*flutter\s*=').hasMatch(line)) {
        continue;
      }
      throw const SdkVersionSyncException(
        '`mise.toml` tools.flutter must be an exact semantic version.',
      );
    }
    final encodedVersion = assignment.group(1)!;
    if (encodedVersion.length < 2 ||
        !((encodedVersion.startsWith('"') && encodedVersion.endsWith('"')) ||
            (encodedVersion.startsWith("'") && encodedVersion.endsWith("'")))) {
      throw const SdkVersionSyncException(
        '`mise.toml` tools.flutter must be a quoted semantic version.',
      );
    }
    final parsedVersion = encodedVersion.substring(
      1,
      encodedVersion.length - 1,
    );
    if (!_semanticVersionPattern.hasMatch(parsedVersion)) {
      throw const SdkVersionSyncException(
        '`mise.toml` tools.flutter must be an exact semantic version.',
      );
    }
    if (flutterVersion != null) {
      throw const SdkVersionSyncException(
        '`mise.toml` contains duplicate tools.flutter entries.',
      );
    }
    flutterVersion = parsedVersion;
  }

  if (flutterVersion == null ||
      !_semanticVersionPattern.hasMatch(flutterVersion)) {
    throw const SdkVersionSyncException(
      '`mise.toml` must contain an exact tools.flutter version.',
    );
  }
  return flutterVersion;
}

Future<_SdkVersions> _readActiveSdk(ProcessRunner processRunner) async {
  final ProcessResult result;
  try {
    result = await processRunner('flutter', const ['--version', '--machine']);
  } on ProcessException catch (error) {
    throw SdkVersionSyncException(
      'Cannot run `flutter --version --machine`: ${error.message}',
    );
  }
  if (result.exitCode != 0) {
    throw SdkVersionSyncException(
      '`flutter --version --machine` exited with ${result.exitCode}: '
      '${result.stderr}',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(result.stdout as String);
  } on FormatException catch (error) {
    throw SdkVersionSyncException(
      '`flutter --version --machine` returned invalid JSON: ${error.message}',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const SdkVersionSyncException(
      '`flutter --version --machine` did not return a JSON object.',
    );
  }

  final flutter = decoded['flutterVersion'];
  final dart = decoded['dartSdkVersion'];
  if (flutter is! String || !_semanticVersionPattern.hasMatch(flutter)) {
    throw const SdkVersionSyncException(
      '`flutterVersion` is missing or is not an exact semantic version.',
    );
  }
  if (dart is! String || !_semanticVersionPattern.hasMatch(dart)) {
    throw const SdkVersionSyncException(
      '`dartSdkVersion` is missing or is not an exact semantic version.',
    );
  }
  return _SdkVersions(flutter: flutter, dart: dart);
}

List<File> _resolveWorkspaceMembers({
  required Directory canonicalRoot,
  required _PubspecDocument rootDocument,
}) {
  final paths = rootDocument.workspacePaths();
  final rootPrefix = '${canonicalRoot.path}${Platform.pathSeparator}';
  final canonicalPaths = <String>{};
  final members = <File>[];

  for (final path in paths) {
    if (path.startsWith('/') ||
        path.codeUnitAt(0) == 92 ||
        RegExp('^[a-zA-Z]:').hasMatch(path) ||
        path.split('/').any((segment) => segment == '.' || segment == '..')) {
      throw SdkVersionSyncException(
        'Workspace member `$path` must be a root-relative path.',
      );
    }

    final directory = Directory(
      '${canonicalRoot.path}${Platform.pathSeparator}'
      '${path.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!directory.existsSync()) {
      throw SdkVersionSyncException(
        'Workspace member directory `$path` does not exist.',
      );
    }
    final canonicalDirectory = Directory(directory.resolveSymbolicLinksSync());
    if (!canonicalDirectory.path.startsWith(rootPrefix)) {
      throw SdkVersionSyncException(
        'Workspace member `$path` resolves outside the repository root.',
      );
    }
    if (!canonicalPaths.add(canonicalDirectory.path)) {
      throw SdkVersionSyncException(
        'Workspace member `$path` resolves to a duplicate directory.',
      );
    }

    final pubspec = _validatedPubspecFile(
      canonicalRoot: canonicalRoot,
      candidate: File(
        '${canonicalDirectory.path}${Platform.pathSeparator}pubspec.yaml',
      ),
      label: 'Workspace member `$path` pubspec.yaml',
    );
    members.add(pubspec);
  }
  return members;
}

File _validatedPubspecFile({
  required Directory canonicalRoot,
  required File candidate,
  required String label,
}) {
  if (FileSystemEntity.typeSync(candidate.path) != FileSystemEntityType.file) {
    throw SdkVersionSyncException(
      '$label is missing or is not a regular file.',
    );
  }
  final canonicalFile = File(candidate.resolveSymbolicLinksSync());
  final rootPrefix = '${canonicalRoot.path}${Platform.pathSeparator}';
  if (!canonicalFile.path.startsWith(rootPrefix)) {
    throw SdkVersionSyncException(
      '$label resolves outside the repository root.',
    );
  }
  return canonicalFile;
}

String _relativePath(Directory root, File file) {
  final prefix = '${root.path}${Platform.pathSeparator}';
  return file.path
      .substring(prefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}

String _decodeQuotedScalar(
  String encoded, {
  required String description,
  required File file,
}) {
  if (encoded.isEmpty) {
    throw SdkVersionSyncException(
      'Empty $description in `${file.path}`.',
    );
  }
  final first = encoded[0];
  if (first != '"' && first != "'") {
    if (encoded.contains('"') || encoded.contains("'")) {
      throw SdkVersionSyncException(
        'Malformed $description in `${file.path}`.',
      );
    }
    return encoded;
  }
  if (encoded.length < 2 || encoded[encoded.length - 1] != first) {
    throw SdkVersionSyncException(
      'Unterminated quoted $description in `${file.path}`.',
    );
  }
  final value = encoded.substring(1, encoded.length - 1);
  if (value.contains(first)) {
    throw SdkVersionSyncException(
      'Escaped quotes are unsupported in $description in `${file.path}`.',
    );
  }
  return value;
}

void _replaceFiles(List<_PendingWrite> pendingWrites) {
  final nonce = Random.secure().nextInt(0x7FFFFFFF);
  final transactionId = '${pid}_$nonce';
  final prepared = <_PreparedWrite>[];
  try {
    for (final pending in pendingWrites) {
      final temporary = File(
        '${pending.file.path}.sdk_sync_$transactionId.tmp',
      );
      final backup = File('${pending.file.path}.sdk_sync_$transactionId.bak');
      if (temporary.existsSync() || backup.existsSync()) {
        throw SdkVersionSyncException(
          'Temporary sync file already exists for `${pending.file.path}`.',
        );
      }
      temporary.writeAsStringSync(pending.updatedContent, flush: true);
      prepared.add(
        _PreparedWrite(pending: pending, temporary: temporary, backup: backup),
      );
    }

    for (final item in prepared) {
      item.pending.file.renameSync(item.backup.path);
      item.temporary.renameSync(item.pending.file.path);
      item.replaced = true;
    }
  } on Object catch (error) {
    final recoveryFailures = <String>[];
    for (final item in prepared.reversed) {
      try {
        if (item.replaced && item.pending.file.existsSync()) {
          item.pending.file.deleteSync();
        }
        if (item.backup.existsSync()) {
          item.backup.renameSync(item.pending.file.path);
        }
        if (item.temporary.existsSync()) {
          item.temporary.deleteSync();
        }
      } on FileSystemException catch (recoveryError) {
        try {
          item.pending.file.writeAsStringSync(
            item.pending.originalContent,
            flush: true,
          );
        } on FileSystemException catch (fallbackError) {
          recoveryFailures.add(
            '${item.pending.file.path}: ${recoveryError.message}; '
            'fallback failed: ${fallbackError.message}',
          );
        }
      }
    }
    if (recoveryFailures.isNotEmpty) {
      throw SdkVersionSyncException(
        'Cannot replace pubspec files: $error. Recovery also failed for '
        '${recoveryFailures.join(', ')}',
      );
    }
    if (error is SdkVersionSyncException) {
      rethrow;
    }
    throw SdkVersionSyncException('Cannot replace pubspec files: $error');
  }

  // Replacement has committed successfully. Backup cleanup must never trigger
  // rollback because some earlier backups might already have been deleted.
  for (final item in prepared) {
    try {
      item.backup.deleteSync();
    } on FileSystemException {
      // A stale backup is safer than deleting a successfully replaced pubspec.
    }
  }
}

final class _PubspecDocument {
  const _PubspecDocument({
    required this.file,
    required this.content,
    required this.lines,
    required this.newline,
    required this.hasTrailingNewline,
    required this.sections,
  });

  factory _PubspecDocument.read(File file) {
    if (!file.existsSync()) {
      throw SdkVersionSyncException('`${file.path}` does not exist.');
    }
    final content = file.readAsStringSync();
    final split = _splitLines(content);
    final sections = <String, _Section>{};
    for (var index = 0; index < split.lines.length; index++) {
      final line = split.lines[index];
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
        continue;
      }
      if (line.startsWith(' ') || line.startsWith('\t')) {
        continue;
      }
      final match = _topLevelKeyPattern.firstMatch(line);
      if (match == null) {
        throw SdkVersionSyncException(
          'Unsupported top-level YAML in `${file.path}` at line ${index + 1}.',
        );
      }
      final name = match.group(1)!;
      if (sections.containsKey(name)) {
        throw SdkVersionSyncException(
          'Duplicate `$name` key in `${file.path}`.',
        );
      }
      sections[name] = _Section(
        start: index,
        end: split.lines.length,
        inlineValue: match.group(2)?.trim() ?? '',
      );
    }
    final ordered = sections.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    for (var index = 0; index < ordered.length - 1; index++) {
      ordered[index].end = ordered[index + 1].start;
    }
    return _PubspecDocument(
      file: file,
      content: content,
      lines: List.unmodifiable(split.lines),
      newline: split.newline,
      hasTrailingNewline: split.hasTrailingNewline,
      sections: Map.unmodifiable(sections),
    );
  }

  final File file;
  final String content;
  final List<String> lines;
  final String newline;
  final bool hasTrailingNewline;
  final Map<String, _Section> sections;

  List<String> workspacePaths() {
    final section = sections['workspace'];
    if (section == null) {
      throw SdkVersionSyncException(
        'Root `${file.path}` must contain a workspace list.',
      );
    }
    if (section.inlineValue.isNotEmpty) {
      throw SdkVersionSyncException(
        'Workspace in `${file.path}` must be a block list.',
      );
    }
    final paths = <String>[];
    for (var index = section.start + 1; index < section.end; index++) {
      final line = lines[index];
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
        continue;
      }
      final match = _workspaceEntryPattern.firstMatch(line);
      if (match == null) {
        throw SdkVersionSyncException(
          'Unsupported workspace entry in `${file.path}` at line ${index + 1}.',
        );
      }
      var encodedPath = match.group(1)!.trim();
      final commentIndex = encodedPath.indexOf(' #');
      if (commentIndex >= 0) {
        encodedPath = encodedPath.substring(0, commentIndex).trimRight();
      }
      final path = _decodeQuotedScalar(
        encodedPath,
        description: 'workspace entry',
        file: file,
      );
      if (!RegExp(r'^[a-zA-Z0-9_./-]+$').hasMatch(path)) {
        throw SdkVersionSyncException(
          'Workspace entry `$path` contains unsupported characters.',
        );
      }
      if (RegExp(r'[*?\[\]{}\\]').hasMatch(path)) {
        throw SdkVersionSyncException(
          'Workspace entry `$path` must not use glob or backslash syntax.',
        );
      }
      paths.add(path);
    }
    if (paths.isEmpty) {
      throw SdkVersionSyncException(
        'Workspace in `${file.path}` must contain at least one member.',
      );
    }
    return paths;
  }

  _DocumentUpdate withSdkVersions({
    required String dartVersion,
    required String flutterVersion,
  }) {
    final environment = sections['environment'];
    if (environment == null || environment.inlineValue.isNotEmpty) {
      throw SdkVersionSyncException(
        '`${file.path}` must contain an environment block.',
      );
    }
    final usesFlutter = _usesFlutterSdk();
    final mutableLines = lines.toList();
    final values = <String, _EnvironmentValue>{};
    for (var index = environment.start + 1; index < environment.end; index++) {
      final line = lines[index];
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
        continue;
      }
      final match = _environmentValuePattern.firstMatch(line);
      if (match == null) {
        throw SdkVersionSyncException(
          'Unsupported environment entry in `${file.path}` at line '
          '${index + 1}.',
        );
      }
      final key = match.group(2)!;
      if (values.containsKey(key)) {
        throw SdkVersionSyncException(
          'Duplicate environment.$key in `${file.path}`.',
        );
      }
      final encodedValue = match.group(4)!.trimRight();
      final decodedValue = _decodeQuotedScalar(
        encodedValue,
        description: 'environment.$key',
        file: file,
      );
      values[key] = _EnvironmentValue(
        index: index,
        value: decodedValue,
        spacing: match.group(3)!,
        quote: encodedValue.startsWith('"') || encodedValue.startsWith("'")
            ? encodedValue[0]
            : '',
        comment: match.group(5) ?? '',
      );
    }

    final changes = <_ValueChange>[];
    final sdk = values['sdk'];
    if (sdk != null && sdk.value != dartVersion) {
      mutableLines[sdk.index] = sdk.render('sdk', dartVersion);
      changes.add(
        _ValueChange(before: 'sdk ${sdk.value}', after: 'sdk $dartVersion'),
      );
    }

    final flutter = values['flutter'];
    if (usesFlutter && flutter != null && flutter.value != flutterVersion) {
      mutableLines[flutter.index] = flutter.render('flutter', flutterVersion);
      changes.add(
        _ValueChange(
          before: 'flutter ${flutter.value}',
          after: 'flutter $flutterVersion',
        ),
      );
    } else if (!usesFlutter && flutter != null) {
      if (flutter.comment.isNotEmpty) {
        throw SdkVersionSyncException(
          'Cannot remove environment.flutter with an inline comment in '
          '`${file.path}`.',
        );
      }
      mutableLines.removeAt(flutter.index);
      changes.add(
        _ValueChange(
          before: 'flutter ${flutter.value}',
          after: 'flutter (removed)',
        ),
      );
    }

    if (sdk == null) {
      mutableLines.insert(environment.start + 1, '  sdk: $dartVersion');
      changes.add(
        _ValueChange(before: 'sdk (missing)', after: 'sdk $dartVersion'),
      );
    }
    if (usesFlutter && flutter == null) {
      final sdkIndex = sdk == null ? environment.start + 1 : sdk.index;
      mutableLines.insert(sdkIndex + 1, '  flutter: $flutterVersion');
      changes.add(
        _ValueChange(
          before: 'flutter (missing)',
          after: 'flutter $flutterVersion',
        ),
      );
    }

    final updatedContent = _joinLines(
      mutableLines,
      newline: newline,
      hasTrailingNewline: hasTrailingNewline,
    );
    return _DocumentUpdate(content: updatedContent, changes: changes);
  }

  bool _usesFlutterSdk() {
    var usesFlutter = false;
    for (final sectionName in const ['dependencies', 'dev_dependencies']) {
      final section = sections[sectionName];
      if (section == null) {
        continue;
      }
      if (section.inlineValue.isNotEmpty) {
        throw SdkVersionSyncException(
          '`$sectionName` in `${file.path}` must use block syntax.',
        );
      }
      String? currentDependency;
      final dependencyNames = <String>{};
      final dependencyProperties = <String, Set<String>>{};
      for (var index = section.start + 1; index < section.end; index++) {
        final line = lines[index];
        if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
          continue;
        }
        final dependency = _dependencyEntryPattern.firstMatch(line);
        if (dependency != null) {
          final name = dependency.group(1)!;
          if (!dependencyNames.add(name)) {
            throw SdkVersionSyncException(
              'Duplicate `$name` dependency in `$sectionName` in '
              '`${file.path}`.',
            );
          }
          final inlineValue = dependency.group(2)!.trim();
          if (inlineValue.startsWith('{') || inlineValue.startsWith('[')) {
            throw SdkVersionSyncException(
              'Inline dependency maps and lists are unsupported in '
              '`${file.path}` at line ${index + 1}.',
            );
          }
          currentDependency = inlineValue.isEmpty ? name : null;
          continue;
        }
        final property = _dependencyPropertyPattern.firstMatch(line);
        if (property == null || currentDependency == null) {
          throw SdkVersionSyncException(
            'Unsupported dependency syntax in `${file.path}` at line '
            '${index + 1}.',
          );
        }
        final propertyName = property.group(1)!;
        final properties = dependencyProperties.putIfAbsent(
          currentDependency,
          () => <String>{},
        );
        if (!properties.add(propertyName)) {
          throw SdkVersionSyncException(
            'Duplicate `$propertyName` for dependency `$currentDependency` in '
            '`${file.path}`.',
          );
        }
        if (propertyName == 'sdk') {
          final sdk = _decodeQuotedScalar(
            property.group(2)!,
            description: '$currentDependency.sdk in $sectionName',
            file: file,
          );
          if (sdk == 'flutter') {
            usesFlutter = true;
          }
        }
      }
    }
    return usesFlutter;
  }
}

final class _Section {
  _Section({required this.start, required this.end, required this.inlineValue});

  final int start;
  int end;
  final String inlineValue;
}

final class _EnvironmentValue {
  const _EnvironmentValue({
    required this.index,
    required this.value,
    required this.spacing,
    required this.quote,
    required this.comment,
  });

  final int index;
  final String value;
  final String spacing;
  final String quote;
  final String comment;

  String render(String key, String newValue) =>
      '  $key:$spacing$quote$newValue$quote$comment';
}

final class _DocumentUpdate {
  const _DocumentUpdate({required this.content, required this.changes});

  final String content;
  final List<_ValueChange> changes;
}

final class _ValueChange {
  const _ValueChange({required this.before, required this.after});

  final String before;
  final String after;
}

final class _SdkVersions {
  const _SdkVersions({required this.flutter, required this.dart});

  final String flutter;
  final String dart;
}

final class _PendingWrite {
  const _PendingWrite({
    required this.file,
    required this.originalContent,
    required this.updatedContent,
  });

  final File file;
  final String originalContent;
  final String updatedContent;
}

final class _PreparedWrite {
  _PreparedWrite({
    required this.pending,
    required this.temporary,
    required this.backup,
  });

  final _PendingWrite pending;
  final File temporary;
  final File backup;
  bool replaced = false;
}

final class _SplitContent {
  const _SplitContent({
    required this.lines,
    required this.newline,
    required this.hasTrailingNewline,
  });

  final List<String> lines;
  final String newline;
  final bool hasTrailingNewline;
}

_SplitContent _splitLines(String content) {
  if (content.contains('\r') && !content.contains('\r\n')) {
    throw const SdkVersionSyncException(
      'Classic Mac line endings are unsupported.',
    );
  }
  final withoutCrLf = content.replaceAll('\r\n', '');
  if (withoutCrLf.contains('\n') && content.contains('\r\n')) {
    throw const SdkVersionSyncException('Mixed line endings are unsupported.');
  }
  final newline = content.contains('\r\n') ? '\r\n' : '\n';
  final hasTrailingNewline = content.endsWith(newline);
  final lines = content.split(newline);
  if (hasTrailingNewline) {
    lines.removeLast();
  }
  return _SplitContent(
    lines: lines,
    newline: newline,
    hasTrailingNewline: hasTrailingNewline,
  );
}

String _joinLines(
  List<String> lines, {
  required String newline,
  required bool hasTrailingNewline,
}) => '${lines.join(newline)}${hasTrailingNewline ? newline : ''}';
