import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../../tools/src/package_dependency_checker.dart';

void main() {
  group('PackageDependencyChecker', () {
    test('アーキテクチャで許可された依存グラフを受け入れる', () {
      final fixture = _createFixture();
      addTearDown(() => fixture.deleteSync(recursive: true));

      final violations = PackageDependencyChecker(
        rootDirectory: fixture,
      ).check();

      expect(violations, isEmpty);
    });

    test('domainからapplicationへの禁止依存を検出する', () {
      final fixture = _createFixture(
        dependencies: {
          ..._defaultDependencies,
          'domain': {'application': '../application'},
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final violations = PackageDependencyChecker(
        rootDirectory: fixture,
      ).check();

      expect(violations, hasLength(1));
      expect(violations.single.sourcePackage, 'domain');
      expect(violations.single.targetPackage, 'application');
      expect(violations.single.reason, contains('not allowed'));
    });

    test('dev_dependencies内の禁止依存を検出する', () {
      final fixture = _createFixture(
        devDependencies: {
          'domain': {'application': '../application'},
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final violations = PackageDependencyChecker(
        rootDirectory: fixture,
      ).check();

      expect(violations, hasLength(1));
      expect(violations.single.sourcePackage, 'domain');
      expect(violations.single.targetPackage, 'application');
      expect(violations.single.reason, contains('dev_dependencies'));
    });

    test('dependency_overrides内の禁止依存を検出する', () {
      final fixture = _createFixture(
        dependencyOverrides: {
          'domain': {'application': '../application'},
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final violations = PackageDependencyChecker(
        rootDirectory: fixture,
      ).check();

      expect(violations, hasLength(1));
      expect(violations.single.sourcePackage, 'domain');
      expect(violations.single.targetPackage, 'application');
      expect(violations.single.reason, contains('dependency_overrides'));
    });

    test('Workspace外のローカルpath依存を検出する', () {
      final fixture = _createFixture(
        dependencies: {
          ..._defaultDependencies,
          'domain': {'hidden': '../hidden'},
        },
        extraPackages: const {'packages/hidden': 'hidden'},
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final violations = PackageDependencyChecker(
        rootDirectory: fixture,
      ).check();

      expect(violations, hasLength(1));
      expect(violations.single.sourcePackage, 'domain');
      expect(violations.single.targetPackage, 'hidden');
      expect(violations.single.reason, contains('Workspace member'));
    });

    test('依存キーとpath解決先のパッケージ名の不一致を検出する', () {
      final fixture = _createFixture(
        dependencies: {
          ..._defaultDependencies,
          'domain': {'not_foundation': '../foundation'},
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final violations = PackageDependencyChecker(
        rootDirectory: fixture,
      ).check();

      expect(violations, hasLength(1));
      expect(violations.single.reason, contains('does not match'));
    });

    test('許可グラフに未登録のWorkspaceメンバーを拒否する', () {
      final fixture = _createFixture(
        workspacePaths: [..._workspacePaths, 'packages/new_layer'],
        extraPackages: const {'packages/new_layer': 'new_layer'},
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      expect(
        () => PackageDependencyChecker(rootDirectory: fixture).check(),
        throwsA(
          isA<PackageDependencyCheckException>().having(
            (error) => error.message,
            'message',
            contains('Missing configuration: new_layer'),
          ),
        ),
      );
    });

    test('pubspec.yamlのトップレベルがMapでなければ拒否する', () {
      final fixture = _createFixture();
      addTearDown(() => fixture.deleteSync(recursive: true));
      File('${fixture.path}/packages/domain/pubspec.yaml').writeAsStringSync(
        '- invalid\n',
      );

      expect(
        () => PackageDependencyChecker(rootDirectory: fixture).check(),
        throwsA(
          isA<PackageDependencyCheckException>().having(
            (error) => error.message,
            'message',
            contains('must contain a YAML map'),
          ),
        ),
      );
    });

    test('WorkspaceがListでなければ拒否する', () {
      final fixture = _createFixture();
      addTearDown(() => fixture.deleteSync(recursive: true));
      File('${fixture.path}/pubspec.yaml').writeAsStringSync(
        'name: fixture\nworkspace: invalid\n',
      );

      expect(
        () => PackageDependencyChecker(rootDirectory: fixture).check(),
        throwsA(
          isA<PackageDependencyCheckException>().having(
            (error) => error.message,
            'message',
            contains('non-empty `workspace` list'),
          ),
        ),
      );
    });

    test('リポジトリ外へ解決されるWorkspaceメンバーを拒否する', () {
      final outside = Directory.systemTemp.createTempSync(
        'dependency_check_outside_',
      );
      final outsideName = outside.path.split(Platform.pathSeparator).last;
      final fixture = _createFixture(
        workspacePaths: [..._workspacePaths, '../$outsideName'],
      );
      addTearDown(() {
        fixture.deleteSync(recursive: true);
        outside.deleteSync(recursive: true);
      });

      expect(
        () => PackageDependencyChecker(rootDirectory: fixture).check(),
        throwsA(
          isA<PackageDependencyCheckException>().having(
            (error) => error.message,
            'message',
            contains('resolves outside the repository root'),
          ),
        ),
      );
    });

    test('リポジトリ外へ解決される依存pathを拒否する', () {
      final outside = Directory.systemTemp.createTempSync(
        'dependency_check_outside_',
      );
      final outsideName = outside.path.split(Platform.pathSeparator).last;
      final fixture = _createFixture(
        dependencies: {
          ..._defaultDependencies,
          'domain': {'outside': '../../../$outsideName'},
        },
      );
      addTearDown(() {
        fixture.deleteSync(recursive: true);
        outside.deleteSync(recursive: true);
      });

      expect(
        () => PackageDependencyChecker(rootDirectory: fixture).check(),
        throwsA(
          isA<PackageDependencyCheckException>().having(
            (error) => error.message,
            'message',
            contains('resolves outside the repository root'),
          ),
        ),
      );
    });

    test('コマンドは違反元と違反先を出力して失敗する', () async {
      final fixture = _createFixture(
        dependencies: {
          ..._defaultDependencies,
          'domain': {'application': '../application'},
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      final output = StringBuffer();
      final errorOutput = StringBuffer();
      final outputSink = IOSink(_StringBufferConsumer(output));
      final errorSink = IOSink(_StringBufferConsumer(errorOutput));
      addTearDown(() async {
        await outputSink.close();
        await errorSink.close();
      });

      final result = runPackageDependencyCheck(
        rootDirectory: fixture,
        standardOut: outputSink,
        standardError: errorSink,
      );
      await errorSink.flush();

      expect(result, 1);
      expect(errorOutput.toString(), contains('domain -> application'));
    });
  });
}

const _workspacePaths = [
  'apps/app',
  'packages/application',
  'packages/dependency_override',
  'packages/designsystem',
  'packages/domain',
  'packages/foundation',
  'packages/infrastructure/mock',
];

const _packageNames = {
  'apps/app': 'material_github_searcher',
  'packages/application': 'application',
  'packages/dependency_override': 'dependency_override',
  'packages/designsystem': 'designsystem',
  'packages/domain': 'domain',
  'packages/foundation': 'foundation',
  'packages/infrastructure/mock': 'infrastructure_mock',
};

const _defaultDependencies = <String, Map<String, String>>{
  'material_github_searcher': {
    'application': '../../packages/application',
    'dependency_override': '../../packages/dependency_override',
    'designsystem': '../../packages/designsystem',
  },
  'application': {
    'domain': '../domain',
    'foundation': '../foundation',
  },
  'dependency_override': {
    'application': '../application',
    'infrastructure_mock': '../infrastructure/mock',
  },
  'designsystem': {'application': '../application'},
  'domain': {'foundation': '../foundation'},
  'infrastructure_mock': {'domain': '../../domain'},
};

Directory _createFixture({
  List<String> workspacePaths = _workspacePaths,
  Map<String, Map<String, String>> dependencies = _defaultDependencies,
  Map<String, Map<String, String>> devDependencies = const {},
  Map<String, Map<String, String>> dependencyOverrides = const {},
  Map<String, String> extraPackages = const {},
}) {
  final root = Directory.systemTemp.createTempSync('dependency_check_');
  File('${root.path}/pubspec.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      'name: fixture\n'
      'workspace:\n'
      '${workspacePaths.map((path) => '  - $path\n').join()}',
    );
  for (final entry in {..._packageNames, ...extraPackages}.entries) {
    final packageDependencies = dependencies[entry.value] ?? const {};
    final packageDevDependencies = devDependencies[entry.value] ?? const {};
    final packageDependencyOverrides =
        dependencyOverrides[entry.value] ?? const {};
    final dependencyYaml = _dependencySectionYaml(
      'dependencies',
      packageDependencies,
    );
    final devDependencyYaml = _dependencySectionYaml(
      'dev_dependencies',
      packageDevDependencies,
    );
    final dependencyOverrideYaml = _dependencySectionYaml(
      'dependency_overrides',
      packageDependencyOverrides,
    );
    File('${root.path}/${entry.key}/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'name: ${entry.value}\n'
        '$dependencyYaml'
        '$devDependencyYaml'
        '$dependencyOverrideYaml',
      );
  }
  return root;
}

String _dependencySectionYaml(
  String section,
  Map<String, String> dependencies,
) {
  if (dependencies.isEmpty) {
    return '';
  }
  final entries = dependencies.entries.map(
    (dependency) =>
        '  ${dependency.key}:\n'
        '    path: ${dependency.value}\n',
  );
  return '$section:\n${entries.join()}';
}

final class _StringBufferConsumer implements StreamConsumer<List<int>> {
  _StringBufferConsumer(this.buffer);

  final StringBuffer buffer;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      buffer.write(String.fromCharCodes(data));
    }
  }

  @override
  Future<void> close() async {}
}
