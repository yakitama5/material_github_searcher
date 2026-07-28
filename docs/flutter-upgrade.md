# Flutterアップグレード手順

このリポジトリではFlutter/DartのSDKバージョンを `mise.toml` で固定管理しており、
各 `pubspec.yaml` の `environment.sdk` と、Flutterを利用するメンバーの
`environment.flutter` も同じバージョンに演算子なしの完全一致で固定している。

そのため、Flutterのバージョンを上げる際は `mise.toml` だけでなく、Workspace内の
全 `pubspec.yaml` も同期ツールで更新する。片方だけを更新すると、
`mise` が解決するFlutterのバージョンと `pubspec.yaml` の制約が食い違い、
`flutter pub get` がSDKバージョン不一致で失敗する。

## 手順

1. `mise.toml` の `tools.flutter` を新しいバージョンに更新する。
2. `mise install` を実行し、指定したバージョンのFlutterを導入する。
3. `mise exec -- flutter --version` で導入されたFlutter/Dartのバージョンを確認する。
4. リポジトリルートで `mise exec -- dart tools/sync_sdk_versions.dart` を実行し、
   ルートと全Workspaceメンバーの `environment.sdk` / `environment.flutter` を同期する。
5. `mise exec -- dart tools/sync_sdk_versions.dart --check` を実行し、差分がないことを
   確認する。
6. リポジトリルートで `mise exec -- flutter pub get` を実行し、単一の
   `pubspec.lock` の `sdks` が
   更新後のバージョンで一致して解決されることを確認する。
7. ルートで `mise exec -- dart analyze --fatal-infos` と
   `mise exec -- dart test test/tools`、`apps/app` で
   `mise exec -- flutter test` を実行し、
   アップグレードに伴う問題が無いことを確認する。
8. 全 `pubspec.yaml` / `pubspec.lock` の差分を含めてコミットする。
