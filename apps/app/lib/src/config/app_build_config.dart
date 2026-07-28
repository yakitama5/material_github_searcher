import 'package:flutter/services.dart' show appFlavor;

/// アプリの実行環境。
enum Flavor {
  /// 開発環境。
  dev,

  /// 本番環境。
  prod;

  /// dart-define の文字列から [Flavor] を生成する。
  static Flavor parse(String value) {
    if (value.isEmpty) {
      throw StateError(
        'Required dart-define "flavor" is not specified. '
        'Pass --dart-define-from-file=flavor/dev.json or flavor/prod.json.',
      );
    }

    return switch (value) {
      'dev' => Flavor.dev,
      'prod' => Flavor.prod,
      _ => throw FormatException(
        'Invalid dart-define "flavor": "$value". Expected "dev" or "prod".',
      ),
    };
  }
}

/// dart-define から読み取るアプリのビルド設定。
final class AppBuildConfig {
  /// ビルド設定を生成する。
  const AppBuildConfig({
    required this.flavor,
    required this.appName,
    required this.appIdAndroid,
    required this.appIdIos,
    required this.appIdSuffix,
  });

  /// dart-define の値を読み取り、ビルド設定を生成する。
  factory AppBuildConfig.fromEnvironment() {
    return AppBuildConfig.fromValues(
      flavor: const String.fromEnvironment('flavor'),
      appName: const String.fromEnvironment('appName'),
      appIdAndroid: const String.fromEnvironment('appIdAndroid'),
      appIdIos: const String.fromEnvironment('appIdIos'),
      appIdSuffix: const String.fromEnvironment('appIdSuffix'),
      // analyze 実行時は --flavor 未指定のため null に定数畳み込みされ、
      // デフォルト値と一致する誤検知が出る。実ビルドでは --flavor の値になる。
      // ignore: avoid_redundant_argument_values
      buildToolFlavor: appFlavor,
    );
  }

  /// 文字列の設定値を検証し、ビルド設定を生成する。
  ///
  /// [buildToolFlavor] は `--flavor` 指定時に Flutter が自動注入する
  /// `package:flutter/services.dart` の `appFlavor`。`--flavor` を伴わない
  /// プラットフォーム（Web 等）では `null` になるため、その場合は検証しない。
  factory AppBuildConfig.fromValues({
    required String flavor,
    required String appName,
    required String appIdAndroid,
    required String appIdIos,
    required String appIdSuffix,
    String? buildToolFlavor,
  }) {
    final parsedFlavor = Flavor.parse(flavor);
    _requireValue('appName', appName);
    _requireValue('appIdAndroid', appIdAndroid);
    _requireValue('appIdIos', appIdIos);
    _requireMatchingBuildToolFlavor(parsedFlavor, buildToolFlavor);

    return AppBuildConfig(
      flavor: parsedFlavor,
      appName: appName,
      appIdAndroid: appIdAndroid,
      appIdIos: appIdIos,
      appIdSuffix: appIdSuffix,
    );
  }

  /// 現在の dart-define に対応するビルド設定。
  static final AppBuildConfig current = AppBuildConfig.fromEnvironment();

  /// 現在の実行環境。
  final Flavor flavor;

  /// ユーザーに表示するアプリ名。
  final String appName;

  /// Android のアプリケーション ID。
  final String appIdAndroid;

  /// iOS の Bundle ID。
  final String appIdIos;

  /// 環境ごとにアプリケーション ID へ付与する接尾辞。
  final String appIdSuffix;

  static void _requireValue(String key, String value) {
    if (value.isEmpty) {
      throw StateError(
        'Required dart-define "$key" is not specified. '
        'Use --dart-define-from-file with a complete flavor configuration.',
      );
    }
  }

  /// Android/iOS の `--flavor` と `--dart-define-from-file` の取り違えを検出する。
  static void _requireMatchingBuildToolFlavor(
    Flavor flavor,
    String? buildToolFlavor,
  ) {
    if (buildToolFlavor == null) {
      return;
    }
    if (buildToolFlavor != flavor.name) {
      throw StateError(
        'Mismatched flavor: --flavor="$buildToolFlavor" but dart-define '
        '"flavor"="${flavor.name}". Ensure --flavor and '
        '--dart-define-from-file reference the same environment.',
      );
    }
  }
}
