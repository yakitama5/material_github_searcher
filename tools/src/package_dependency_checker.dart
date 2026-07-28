import 'dart:io';

import 'package:yaml/yaml.dart';

/// `docs/ARCHITECTURE.md` に定義したパッケージ間の直接依存を表す。
///
/// 推移的な依存は許可しない。たとえば `app` は `application` に直接依存できるが、
/// `application` の依存先である `domain` へ直接依存することはできない。
const allowedPackageDependencies = <String, Set<String>>{
  'material_github_searcher': {
    'application',
    'dependency_override',
    'designsystem',
  },
  'designsystem': {'application'},
  'application': {'domain', 'foundation'},
  'dependency_override': {'application', 'infrastructure_mock'},
  'infrastructure_mock': {'domain'},
  'domain': {'foundation'},
  'foundation': {},
};

const _dependencySections = [
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// リポジトリのローカル `path` 依存が許可グラフに従っているか検証する。
final class PackageDependencyChecker {
  PackageDependencyChecker({required this.rootDirectory});

  /// ルート `pubspec.yaml` と Workspace メンバーを含むディレクトリ。
  final Directory rootDirectory;

  /// すべての違反をまとめて返す。
  List<PackageDependencyViolation> check() {
    final canonicalRoot = _canonicalDirectory(rootDirectory);
    final rootPubspec = File('${canonicalRoot.path}/pubspec.yaml');
    final rootYaml = _loadPubspec(rootPubspec);
    final workspacePaths = _readWorkspacePaths(rootYaml, rootPubspec);
    final members = <String, _WorkspaceMember>{};
    final membersByPath = <String, _WorkspaceMember>{};

    for (final workspacePath in workspacePaths) {
      final directory = _resolveWorkspaceDirectory(
        canonicalRoot,
        workspacePath,
      );
      final pubspec = File('${directory.path}/pubspec.yaml');
      final yaml = _loadPubspec(pubspec);
      final name = _readPackageName(yaml, pubspec);
      if (members.containsKey(name)) {
        throw PackageDependencyCheckException(
          'Workspace package name `$name` is duplicated.',
        );
      }
      final member = _WorkspaceMember(
        name: name,
        directory: directory,
        pubspec: pubspec,
        yaml: yaml,
      );
      members[name] = member;
      membersByPath[directory.path] = member;
    }

    final configuredPackages = allowedPackageDependencies.keys.toSet();
    final workspacePackages = members.keys.toSet();
    if (!_sameSet(configuredPackages, workspacePackages)) {
      final missing = workspacePackages.difference(configuredPackages).toList()
        ..sort();
      final stale = configuredPackages.difference(workspacePackages).toList()
        ..sort();
      final missingMessage = missing.isEmpty
          ? ''
          : ' Missing configuration: ${missing.join(', ')}.';
      final staleMessage = stale.isEmpty
          ? ''
          : ' Unknown configured packages: ${stale.join(', ')}.';
      throw PackageDependencyCheckException(
        'The allowed dependency graph does not match the Pub Workspace.'
        '$missingMessage'
        '$staleMessage',
      );
    }

    final violations = <PackageDependencyViolation>[];
    for (final member in members.values) {
      for (final section in _dependencySections) {
        final dependencies = member.yaml[section];
        if (dependencies == null) {
          continue;
        }
        if (dependencies is! YamlMap) {
          throw PackageDependencyCheckException(
            '`${member.pubspec.path}` must define `$section` as a map.',
          );
        }
        for (final entry in dependencies.entries) {
          final dependencyName = entry.key;
          final specification = entry.value;
          if (dependencyName is! String || specification is! YamlMap) {
            continue;
          }
          final path = specification['path'];
          if (path == null) {
            continue;
          }
          if (path is! String || path.trim().isEmpty) {
            throw PackageDependencyCheckException(
              '`${member.pubspec.path}` has an invalid path dependency '
              'for `$dependencyName` in `$section`.',
            );
          }

          final targetDirectory = _resolveDependencyDirectory(
            canonicalRoot: canonicalRoot,
            source: member,
            path: path,
          );
          final target = membersByPath[targetDirectory.path];
          if (target == null) {
            violations.add(
              PackageDependencyViolation(
                sourcePackage: member.name,
                targetPackage: dependencyName,
                reason:
                    'path `$path` in `$section` does not point to a '
                    'Pub Workspace member',
              ),
            );
            continue;
          }
          if (dependencyName != target.name) {
            violations.add(
              PackageDependencyViolation(
                sourcePackage: member.name,
                targetPackage: target.name,
                reason:
                    'dependency key `$dependencyName` in `$section` does '
                    'not match the target package name `${target.name}`',
              ),
            );
            continue;
          }
          if (!allowedPackageDependencies[member.name]!.contains(target.name)) {
            violations.add(
              PackageDependencyViolation(
                sourcePackage: member.name,
                targetPackage: target.name,
                reason:
                    'dependency in `$section` is not allowed by '
                    'docs/ARCHITECTURE.md',
              ),
            );
          }
        }
      }
    }
    return violations;
  }
}

/// 検証コマンドを実行し、プロセス終了コードを返す。
int runPackageDependencyCheck({
  required Directory rootDirectory,
  required IOSink standardOut,
  required IOSink standardError,
}) {
  try {
    final violations = PackageDependencyChecker(
      rootDirectory: rootDirectory,
    ).check();
    if (violations.isEmpty) {
      standardOut.writeln(
        'Package dependencies match docs/ARCHITECTURE.md.',
      );
      return 0;
    }
    standardError.writeln('Disallowed package dependencies found:');
    for (final violation in violations) {
      standardError.writeln(
        '- ${violation.sourcePackage} -> ${violation.targetPackage}: '
        '${violation.reason}',
      );
    }
    return 1;
  } on PackageDependencyCheckException catch (error) {
    standardError.writeln('Failed to check package dependencies: $error');
    return 1;
  } on FileSystemException catch (error) {
    standardError.writeln(
      'Failed to check package dependencies: ${error.message} '
      '(${error.path ?? 'unknown path'})',
    );
    return 1;
  } on YamlException catch (error) {
    standardError.writeln('Failed to parse a pubspec.yaml: $error');
    return 1;
  }
}

/// 検出したパッケージ間依存の違反。
final class PackageDependencyViolation {
  const PackageDependencyViolation({
    required this.sourcePackage,
    required this.targetPackage,
    required this.reason,
  });

  final String sourcePackage;
  final String targetPackage;
  final String reason;
}

/// 設定または Workspace 構造が検証できない場合のエラー。
final class PackageDependencyCheckException implements Exception {
  const PackageDependencyCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class _WorkspaceMember {
  const _WorkspaceMember({
    required this.name,
    required this.directory,
    required this.pubspec,
    required this.yaml,
  });

  final String name;
  final Directory directory;
  final File pubspec;
  final YamlMap yaml;
}

YamlMap _loadPubspec(File file) {
  if (!file.existsSync()) {
    throw PackageDependencyCheckException(
      '`${file.path}` does not exist.',
    );
  }
  final yaml = loadYaml(file.readAsStringSync());
  if (yaml is! YamlMap) {
    throw PackageDependencyCheckException(
      '`${file.path}` must contain a YAML map.',
    );
  }
  return yaml;
}

List<String> _readWorkspacePaths(YamlMap yaml, File pubspec) {
  final workspace = yaml['workspace'];
  if (workspace is! YamlList || workspace.isEmpty) {
    throw PackageDependencyCheckException(
      '`${pubspec.path}` must define a non-empty `workspace` list.',
    );
  }
  final paths = <String>[];
  for (final value in workspace) {
    if (value is! String || value.trim().isEmpty) {
      throw PackageDependencyCheckException(
        '`${pubspec.path}` contains an invalid Workspace member path.',
      );
    }
    paths.add(value);
  }
  return paths;
}

String _readPackageName(YamlMap yaml, File pubspec) {
  final name = yaml['name'];
  if (name is! String || name.trim().isEmpty) {
    throw PackageDependencyCheckException(
      '`${pubspec.path}` must define a package name.',
    );
  }
  return name;
}

Directory _resolveWorkspaceDirectory(Directory root, String path) {
  final directory = Directory('${root.path}/$path');
  final canonical = _canonicalDirectory(directory);
  if (!_isWithin(root, canonical)) {
    throw PackageDependencyCheckException(
      'Workspace member `$path` resolves outside the repository root.',
    );
  }
  return canonical;
}

Directory _resolveDependencyDirectory({
  required Directory canonicalRoot,
  required _WorkspaceMember source,
  required String path,
}) {
  final directory = Directory('${source.directory.path}/$path');
  final canonical = _canonicalDirectory(directory);
  if (!_isWithin(canonicalRoot, canonical)) {
    throw PackageDependencyCheckException(
      'Path dependency `$path` in `${source.pubspec.path}` resolves outside '
      'the repository root.',
    );
  }
  return canonical;
}

Directory _canonicalDirectory(Directory directory) {
  try {
    return Directory(directory.resolveSymbolicLinksSync());
  } on FileSystemException {
    throw PackageDependencyCheckException(
      'Directory `${directory.path}` does not exist or cannot be resolved.',
    );
  }
}

bool _isWithin(Directory root, Directory child) {
  final separator = Platform.pathSeparator;
  return child.path == root.path ||
      child.path.startsWith('${root.path}$separator');
}

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
