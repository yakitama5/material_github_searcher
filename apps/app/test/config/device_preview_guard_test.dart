import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/config/device_preview_guard.dart';

const _devConfig = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

const _prodConfig = AppBuildConfig(
  flavor: Flavor.prod,
  appName: 'Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '',
);

void main() {
  group('assertDevicePreviewAllowed', () {
    test('Dev Flavorかつdebugモードでは例外を投げない', () {
      expect(
        () => assertDevicePreviewAllowed(_devConfig, isReleaseMode: false),
        returnsNormally,
      );
    });

    test('releaseモードでは起動を拒否する', () {
      expect(
        () => assertDevicePreviewAllowed(_devConfig, isReleaseMode: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('release mode'),
          ),
        ),
      );
    });

    test('Prod Flavorでは起動を拒否する', () {
      expect(
        () => assertDevicePreviewAllowed(_prodConfig, isReleaseMode: false),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('dev flavor'),
          ),
        ),
      );
    });
  });
}
