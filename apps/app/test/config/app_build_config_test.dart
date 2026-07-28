import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';

void main() {
  group('AppBuildConfig.fromValues', () {
    test('dev の設定値を読み取れる', () {
      final config = AppBuildConfig.fromValues(
        flavor: 'dev',
        appName: 'Dev - Material GitHub Searcher',
        appIdAndroid: 'com.example.material_github_searcher',
        appIdIos: 'com.example.materialGithubSearcher',
        appIdSuffix: '.dev',
      );

      expect(config.flavor, Flavor.dev);
      expect(config.appName, 'Dev - Material GitHub Searcher');
      expect(config.appIdAndroid, 'com.example.material_github_searcher');
      expect(config.appIdIos, 'com.example.materialGithubSearcher');
      expect(config.appIdSuffix, '.dev');
    });

    test('prod の設定値を読み取れる', () {
      final config = AppBuildConfig.fromValues(
        flavor: 'prod',
        appName: 'Material GitHub Searcher',
        appIdAndroid: 'com.example.material_github_searcher',
        appIdIos: 'com.example.materialGithubSearcher',
        appIdSuffix: '',
      );

      expect(config.flavor, Flavor.prod);
      expect(
        config.appIdSuffix,
        isEmpty,
        reason: 'Prod では suffix の空文字を正当値として扱う',
      );
    });

    test('Flavor が未指定の場合は起動方法を含むエラーになる', () {
      expect(
        () => AppBuildConfig.fromValues(
          flavor: '',
          appName: 'Material GitHub Searcher',
          appIdAndroid: 'com.example.material_github_searcher',
          appIdIos: 'com.example.materialGithubSearcher',
          appIdSuffix: '',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('flavor'), contains('--dart-define-from-file')),
          ),
        ),
      );
    });

    test('全 dart-define が未指定でも Flavor の不足を最初に報告する', () {
      expect(
        () => AppBuildConfig.fromValues(
          flavor: '',
          appName: '',
          appIdAndroid: '',
          appIdIos: '',
          appIdSuffix: '',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('"flavor"'),
          ),
        ),
      );
    });

    test('Flavor が不正な場合は許可された値を含むエラーになる', () {
      expect(
        () => AppBuildConfig.fromValues(
          flavor: 'staging',
          appName: 'Material GitHub Searcher',
          appIdAndroid: 'com.example.material_github_searcher',
          appIdIos: 'com.example.materialGithubSearcher',
          appIdSuffix: '',
        ),
        throwsA(
          isA<FormatException>()
              .having((error) => error.message, 'message', contains('staging'))
              .having(
                (error) => error.message,
                'message',
                allOf(contains('dev'), contains('prod')),
              ),
        ),
      );
    });

    test('buildToolFlavor が未指定(null)の場合は検証されない', () {
      final config = AppBuildConfig.fromValues(
        flavor: 'dev',
        appName: 'Dev - Material GitHub Searcher',
        appIdAndroid: 'com.example.material_github_searcher',
        appIdIos: 'com.example.materialGithubSearcher',
        appIdSuffix: '.dev',
      );

      expect(config.flavor, Flavor.dev);
    });

    test('buildToolFlavor が dart-define の flavor と一致する場合は生成できる', () {
      final config = AppBuildConfig.fromValues(
        flavor: 'dev',
        appName: 'Dev - Material GitHub Searcher',
        appIdAndroid: 'com.example.material_github_searcher',
        appIdIos: 'com.example.materialGithubSearcher',
        appIdSuffix: '.dev',
        buildToolFlavor: 'dev',
      );

      expect(config.flavor, Flavor.dev);
    });

    test('buildToolFlavor が dart-define の flavor と不一致の場合はエラーになる', () {
      expect(
        () => AppBuildConfig.fromValues(
          flavor: 'prod',
          appName: 'Material GitHub Searcher',
          appIdAndroid: 'com.example.material_github_searcher',
          appIdIos: 'com.example.materialGithubSearcher',
          appIdSuffix: '',
          buildToolFlavor: 'dev',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('--flavor'), contains('dev'), contains('prod')),
          ),
        ),
      );
    });

    for (final key in ['appName', 'appIdAndroid', 'appIdIos']) {
      test('$key が未指定の場合はキー名を含むエラーになる', () {
        final values = <String, String>{
          'appName': 'Material GitHub Searcher',
          'appIdAndroid': 'com.example.material_github_searcher',
          'appIdIos': 'com.example.materialGithubSearcher',
        }..[key] = '';

        expect(
          () => AppBuildConfig.fromValues(
            flavor: 'prod',
            appName: values['appName']!,
            appIdAndroid: values['appIdAndroid']!,
            appIdIos: values['appIdIos']!,
            appIdSuffix: '',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(key),
            ),
          ),
        );
      });
    }
  });
}
