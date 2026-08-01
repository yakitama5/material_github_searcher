import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/license/register_app_license.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(LicenseRegistry.reset);
  });

  test('アプリ名で識別できるMITライセンスのエントリを登録する', () async {
    registerAppLicense('Material GitHub Searcher');

    final entries = await LicenseRegistry.licenses.toList();

    expect(entries, hasLength(1));
    expect(entries.single.packages, ['Material GitHub Searcher']);
    expect(
      entries.single.paragraphs.map((p) => p.text).join('\n'),
      contains('MIT License'),
    );
  });

  test('createAppはComposition Root起動時にアプリ名でライセンスを登録する', () async {
    createApp(config: _config);

    final entries = await LicenseRegistry.licenses.toList();

    expect(entries, hasLength(1));
    expect(entries.single.packages, [_config.appName]);
    expect(
      entries.single.paragraphs.map((p) => p.text).join('\n'),
      contains('MIT License'),
    );
  });
}
