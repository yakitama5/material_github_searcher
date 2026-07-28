import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tools/src/sdk_version_sync.dart';

void main() {
  group('SdkVersionSynchronizer', () {
    test('全パッケージを同期しFlutter非依存パッケージの制約を削除する', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.11.0',
          members: const ['apps/app', 'packages/domain'],
        ),
        members: {
          'apps/app': _flutterPubspec(dart: '3.11.0', flutter: '3.43.0'),
          'packages/domain': _dartPubspec(
            dart: '3.11.0',
            staleFlutter: '3.43.0',
          ),
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final result = await _synchronizer(fixture).synchronize(checkOnly: false);

      expect(result.changes, hasLength(5));
      expect(
        File('${fixture.path}/pubspec.yaml').readAsStringSync(),
        contains('  sdk: 3.12.2'),
      );
      expect(
        File('${fixture.path}/apps/app/pubspec.yaml').readAsStringSync(),
        contains('  flutter: 3.44.8'),
      );
      expect(
        File('${fixture.path}/packages/domain/pubspec.yaml').readAsStringSync(),
        isNot(contains('  flutter:')),
      );
    });

    test('--check相当では差分を検出しても書き込まない', () async {
      final rootContent = _rootPubspec(
        dartVersion: '3.11.0',
        members: const ['apps/app'],
      );
      final fixture = _createFixture(
        rootPubspec: rootContent,
        members: {
          'apps/app': _flutterPubspec(dart: '3.11.0', flutter: '3.43.0'),
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final result = await _synchronizer(fixture).synchronize(checkOnly: true);

      expect(result.changes, isNotEmpty);
      expect(
        File('${fixture.path}/pubspec.yaml').readAsStringSync(),
        rootContent,
      );
    });

    test('後半メンバーの検証失敗時はどのファイルも変更しない', () async {
      final rootContent = _rootPubspec(
        dartVersion: '3.11.0',
        members: const ['apps/app', 'packages/broken'],
      );
      final appContent = _flutterPubspec(dart: '3.11.0', flutter: '3.43.0');
      final fixture = _createFixture(
        rootPubspec: rootContent,
        members: {
          'apps/app': appContent,
          'packages/broken': 'name: broken\nenvironment: inline\n',
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await expectLater(
        _synchronizer(fixture).synchronize(checkOnly: false),
        throwsA(isA<SdkVersionSyncException>()),
      );
      expect(
        File('${fixture.path}/pubspec.yaml').readAsStringSync(),
        rootContent,
      );
      expect(
        File('${fixture.path}/apps/app/pubspec.yaml').readAsStringSync(),
        appContent,
      );
    });

    test('miseと実行中Flutterが不一致なら更新しない', () async {
      final rootContent = _rootPubspec(
        dartVersion: '3.11.0',
        members: const ['packages/domain'],
      );
      final fixture = _createFixture(
        rootPubspec: rootContent,
        members: {'packages/domain': _dartPubspec(dart: '3.11.0')},
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      final synchronizer = SdkVersionSynchronizer(
        rootDirectory: fixture,
        processRunner: (_, _) async => _flutterResult(flutter: '3.45.0'),
      );

      await expectLater(
        synchronizer.synchronize(checkOnly: false),
        throwsA(isA<SdkVersionSyncException>()),
      );
      expect(
        File('${fixture.path}/pubspec.yaml').readAsStringSync(),
        rootContent,
      );
    });

    test('Flutterバージョン取得コマンドの失敗時は更新しない', () async {
      await _expectActiveSdkFailureDoesNotWrite(
        result: ProcessResult(1, 1, '', 'command failed'),
        errorFragment: 'exited with 1',
      );
    });

    test('Flutterバージョン取得結果が不正なJSONなら更新しない', () async {
      await _expectActiveSdkFailureDoesNotWrite(
        result: ProcessResult(1, 0, 'not-json', ''),
        errorFragment: 'invalid JSON',
      );
    });

    test('Flutterバージョン取得結果にFlutterバージョンがなければ更新しない', () async {
      await _expectActiveSdkFailureDoesNotWrite(
        result: ProcessResult(
          1,
          0,
          jsonEncode({'dartSdkVersion': '3.12.2'}),
          '',
        ),
        errorFragment: 'flutterVersion',
      );
    });

    test('Flutterバージョン取得結果にDartバージョンがなければ更新しない', () async {
      await _expectActiveSdkFailureDoesNotWrite(
        result: ProcessResult(
          1,
          0,
          jsonEncode({'flutterVersion': '3.44.8'}),
          '',
        ),
        errorFragment: 'dartSdkVersion',
      );
    });

    test('ルート外へ解決されるWorkspaceメンバーを拒否する', () async {
      final outside = Directory.systemTemp.createTempSync('sdk_sync_outside_');
      final fixture = Directory.systemTemp.createTempSync('sdk_sync_fixture_');
      addTearDown(() {
        fixture.deleteSync(recursive: true);
        outside.deleteSync(recursive: true);
      });
      File('${fixture.path}/mise.toml').writeAsStringSync(
        '[tools]\nflutter = "3.44.8"\n',
      );
      File('${fixture.path}/pubspec.yaml').writeAsStringSync(
        _rootPubspec(dartVersion: '3.11.0', members: const ['../outside']),
      );

      await expectLater(
        _synchronizer(fixture).synchronize(checkOnly: true),
        throwsA(isA<SdkVersionSyncException>()),
      );
    });

    test('CRLFとコメントを保持する', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.11.0',
          members: const ['packages/domain'],
        ).replaceAll('\n', '\r\n'),
        members: {
          'packages/domain': _dartPubspec(dart: '3.11.0')
              .replaceAll(
                '  sdk: 3.11.0',
                '  sdk: 3.11.0 # keep',
              )
              .replaceAll('\n', '\r\n'),
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await _synchronizer(fixture).synchronize(checkOnly: false);

      final content = File(
        '${fixture.path}/packages/domain/pubspec.yaml',
      ).readAsStringSync();
      expect(content, contains('  sdk: 3.12.2 # keep\r\n'));
      expect(content.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('sdk欠落時も既存flutter行を壊さず追加する', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.12.2',
          members: const ['apps/app', 'packages/domain'],
        ),
        members: {
          'apps/app':
              'name: app\n'
              'environment:\n'
              '  flutter: 3.43.0\n'
              'dependencies:\n'
              '  flutter:\n'
              '    sdk: flutter\n',
          'packages/domain':
              'name: domain\n'
              'environment:\n'
              '  flutter: 3.43.0\n'
              'dependencies:\n',
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await _synchronizer(fixture).synchronize(checkOnly: false);

      final app = File(
        '${fixture.path}/apps/app/pubspec.yaml',
      ).readAsStringSync();
      expect(app, contains('  sdk: 3.12.2\n  flutter: 3.44.8\n'));
      final domain = File(
        '${fixture.path}/packages/domain/pubspec.yaml',
      ).readAsStringSync();
      expect(domain, contains('  sdk: 3.12.2\n'));
      expect(domain, isNot(contains('  flutter:')));
    });

    test('引用符とinline commentを保持する', () async {
      final fixture = _createFixture(
        rootPubspec:
            'name: workspace\n'
            'environment:\n'
            '  sdk: "3.11.0" # root\n'
            'workspace:\n'
            "  - 'apps/app' # app\n",
        members: {
          'apps/app':
              'name: app\n'
              'environment:\n'
              "  sdk: '3.11.0' # dart\n"
              '  flutter: "3.43.0" # flutter\n'
              'dependencies:\n'
              '  flutter:\n'
              '    sdk: flutter\n',
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await _synchronizer(fixture).synchronize(checkOnly: false);

      expect(
        File('${fixture.path}/pubspec.yaml').readAsStringSync(),
        contains('  sdk: "3.12.2" # root'),
      );
      final app = File(
        '${fixture.path}/apps/app/pubspec.yaml',
      ).readAsStringSync();
      expect(app, contains("  sdk: '3.12.2' # dart"));
      expect(app, contains('  flutter: "3.44.8" # flutter'));
    });

    test('pubspec symlinkによるルート外への越境を拒否する', () async {
      if (Platform.isWindows) {
        return;
      }
      final outside = Directory.systemTemp.createTempSync('sdk_sync_outside_');
      final fixture = Directory.systemTemp.createTempSync('sdk_sync_fixture_');
      addTearDown(() {
        fixture.deleteSync(recursive: true);
        outside.deleteSync(recursive: true);
      });
      File('${fixture.path}/mise.toml').writeAsStringSync(
        '[tools]\nflutter = "3.44.8"\n',
      );
      File('${fixture.path}/pubspec.yaml').writeAsStringSync(
        _rootPubspec(
          dartVersion: '3.12.2',
          members: const ['packages/domain'],
        ),
      );
      final member = Directory('${fixture.path}/packages/domain')
        ..createSync(recursive: true);
      final outsidePubspec = File('${outside.path}/pubspec.yaml')
        ..writeAsStringSync(_dartPubspec(dart: '3.11.0'));
      Link('${member.path}/pubspec.yaml').createSync(outsidePubspec.path);

      await expectLater(
        _synchronizer(fixture).synchronize(checkOnly: false),
        throwsA(isA<SdkVersionSyncException>()),
      );
      expect(outsidePubspec.readAsStringSync(), contains('  sdk: 3.11.0'));
    });

    test('Flutter検出後にある不正な依存構造も拒否する', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.12.2',
          members: const ['apps/app'],
        ),
        members: {
          'apps/app':
              '${_flutterPubspec(dart: '3.11.0', flutter: '3.43.0')}'
              '   malformed: value\n',
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await expectLater(
        _synchronizer(fixture).synchronize(checkOnly: false),
        throwsA(isA<SdkVersionSyncException>()),
      );
      expect(
        File('${fixture.path}/apps/app/pubspec.yaml').readAsStringSync(),
        contains('  sdk: 3.11.0'),
      );
    });

    test('dev dependencyだけがFlutter SDKでもFlutterパッケージとして扱う', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.12.2',
          members: const ['packages/widget'],
        ),
        members: {
          'packages/widget':
              'name: widget\n'
              'environment:\n'
              '  sdk: 3.12.2\n'
              'dev_dependencies:\n'
              '  flutter_test:\n'
              '    sdk: flutter\n',
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await _synchronizer(fixture).synchronize(checkOnly: false);

      expect(
        File('${fixture.path}/packages/widget/pubspec.yaml').readAsStringSync(),
        contains('  flutter: 3.44.8'),
      );
    });

    test('引用符付きFlutter SDK依存もFlutterパッケージとして扱う', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.12.2',
          members: const ['apps/double_quote', 'apps/single_quote'],
        ),
        members: {
          'apps/double_quote':
              'name: double_quote\n'
              'environment:\n'
              '  sdk: 3.12.2\n'
              'dependencies:\n'
              '  flutter:\n'
              '    sdk: "flutter"\n',
          'apps/single_quote':
              'name: single_quote\n'
              'environment:\n'
              '  sdk: 3.12.2\n'
              'dev_dependencies:\n'
              '  flutter_test:\n'
              "    sdk: 'flutter'\n",
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      await _synchronizer(fixture).synchronize(checkOnly: false);

      for (final member in const ['double_quote', 'single_quote']) {
        expect(
          File('${fixture.path}/apps/$member/pubspec.yaml').readAsStringSync(),
          contains('  flutter: 3.44.8'),
        );
      }
    });
  });

  group('runSdkVersionSync', () {
    test('不正な引数をusageエラーにする', () async {
      final fixture = Directory.systemTemp.createTempSync('sdk_sync_fixture_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      final out = StringBuffer();
      final error = StringBuffer();

      final exitCode = await runSdkVersionSync(
        arguments: const ['--unknown'],
        rootDirectory: fixture,
        standardOut: out,
        standardError: error,
      );

      expect(exitCode, 64);
      expect(error.toString(), contains('Usage:'));
    });

    test('古い制約とpackage configなしで実プロセスから同期できる', () async {
      if (Platform.isWindows) {
        return;
      }
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.11.0',
          members: const ['apps/app'],
        ),
        members: {
          'apps/app': _flutterPubspec(dart: '3.11.0', flutter: '3.43.0'),
        },
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      final fixtureTools = Directory('${fixture.path}/tools/src')
        ..createSync(recursive: true);
      File('tools/sync_sdk_versions.dart').copySync(
        '${fixture.path}/tools/sync_sdk_versions.dart',
      );
      File('tools/src/sdk_version_sync.dart').copySync(
        '${fixtureTools.path}/sdk_version_sync.dart',
      );
      final fakeBin = Directory('${fixture.path}/fake_bin')..createSync();
      final machineJson = jsonEncode({
        'flutterVersion': '3.44.8',
        'dartSdkVersion': '3.12.2',
      });
      final fakeFlutter = File('${fakeBin.path}/flutter')
        ..writeAsStringSync(
          '#!/bin/sh\n'
          "printf '%s\\n' '$machineJson'\n",
        );
      final chmod = await Process.run('chmod', ['+x', fakeFlutter.path]);
      expect(chmod.exitCode, 0);
      final script = File('${fixture.path}/tools/sync_sdk_versions.dart');
      final path = '${fakeBin.path}:${Platform.environment['PATH'] ?? ''}';

      final result = await Process.run(
        Platform.resolvedExecutable,
        [script.path],
        workingDirectory: fixture.path,
        environment: {...Platform.environment, 'PATH': path},
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(Directory('${fixture.path}/.dart_tool').existsSync(), isFalse);
      expect(
        File('${fixture.path}/apps/app/pubspec.yaml').readAsStringSync(),
        contains('  flutter: 3.44.8'),
      );
    });

    test('--checkは差分を終了コード1で報告して書き込まない', () async {
      final fixture = _createFixture(
        rootPubspec: _rootPubspec(
          dartVersion: '3.11.0',
          members: const ['packages/domain'],
        ),
        members: {'packages/domain': _dartPubspec(dart: '3.11.0')},
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      final before = File('${fixture.path}/pubspec.yaml').readAsStringSync();

      final exitCode = await runSdkVersionSync(
        arguments: const ['--check'],
        rootDirectory: fixture,
        standardOut: StringBuffer(),
        standardError: StringBuffer(),
        processRunner: (_, _) async => _flutterResult(),
      );

      expect(exitCode, 1);
      expect(File('${fixture.path}/pubspec.yaml').readAsStringSync(), before);
    });
  });
}

SdkVersionSynchronizer _synchronizer(Directory fixture) =>
    SdkVersionSynchronizer(
      rootDirectory: fixture,
      processRunner: (_, _) async => _flutterResult(),
    );

ProcessResult _flutterResult({
  String flutter = '3.44.8',
  String dart = '3.12.2',
}) => ProcessResult(
  1,
  0,
  jsonEncode({'flutterVersion': flutter, 'dartSdkVersion': dart}),
  '',
);

Future<void> _expectActiveSdkFailureDoesNotWrite({
  required ProcessResult result,
  required String errorFragment,
}) async {
  final rootContent = _rootPubspec(
    dartVersion: '3.11.0',
    members: const ['packages/domain'],
  );
  final memberContent = _dartPubspec(dart: '3.11.0');
  final fixture = _createFixture(
    rootPubspec: rootContent,
    members: {'packages/domain': memberContent},
  );
  addTearDown(() => fixture.deleteSync(recursive: true));
  final synchronizer = SdkVersionSynchronizer(
    rootDirectory: fixture,
    processRunner: (_, _) async => result,
  );

  await expectLater(
    synchronizer.synchronize(checkOnly: false),
    throwsA(
      isA<SdkVersionSyncException>().having(
        (error) => error.message,
        'message',
        contains(errorFragment),
      ),
    ),
  );
  expect(File('${fixture.path}/pubspec.yaml').readAsStringSync(), rootContent);
  expect(
    File('${fixture.path}/packages/domain/pubspec.yaml').readAsStringSync(),
    memberContent,
  );
}

Directory _createFixture({
  required String rootPubspec,
  required Map<String, String> members,
}) {
  final root = Directory.systemTemp.createTempSync('sdk_sync_fixture_');
  File('${root.path}/mise.toml').writeAsStringSync(
    '[tools]\nflutter = "3.44.8"\n',
  );
  File('${root.path}/pubspec.yaml').writeAsStringSync(rootPubspec);
  for (final entry in members.entries) {
    final directory = Directory('${root.path}/${entry.key}')
      ..createSync(recursive: true);
    File('${directory.path}/pubspec.yaml').writeAsStringSync(entry.value);
  }
  return root;
}

String _rootPubspec({
  required String dartVersion,
  required List<String> members,
}) =>
    'name: workspace\n'
    'environment:\n'
    '  sdk: $dartVersion\n'
    'workspace:\n'
    '${members.map((member) => '  - $member').join('\n')}\n';

String _flutterPubspec({required String dart, required String flutter}) =>
    'name: app\n'
    'environment:\n'
    '  sdk: $dart\n'
    '  flutter: $flutter\n'
    'dependencies:\n'
    '  flutter:\n'
    '    sdk: flutter\n';

String _dartPubspec({required String dart, String? staleFlutter}) =>
    'name: domain\n'
    'environment:\n'
    '  sdk: $dart\n'
    '${staleFlutter == null ? '' : '  flutter: $staleFlutter\n'}'
    'dependencies:\n';
