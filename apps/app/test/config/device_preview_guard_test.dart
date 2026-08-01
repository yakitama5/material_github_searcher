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
    test('Dev FlavorかつWebでは例外を投げない（release build相当でもbuild modeを問わず許可する）', () {
      expect(
        () => assertDevicePreviewAllowed(_devConfig, isWeb: true),
        returnsNormally,
      );
    });

    test('Prod Flavorでは起動を拒否する', () {
      expect(
        () => assertDevicePreviewAllowed(_prodConfig, isWeb: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('dev flavor'),
          ),
        ),
      );
    });

    test('Web以外のPlatformでは起動を拒否する', () {
      expect(
        () => assertDevicePreviewAllowed(_devConfig, isWeb: false),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Web-only'),
          ),
        ),
      );
    });

    test('Prod Flavorかつ Web以外では起動を拒否する（Android/iOSのProd誤起動を防ぐ）', () {
      expect(
        () => assertDevicePreviewAllowed(_prodConfig, isWeb: false),
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
