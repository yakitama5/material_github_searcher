# Flutterアップグレード手順

このリポジトリではFlutter/DartのSDKバージョンを `mise.toml` で固定管理しており、
`pubspec.yaml` の `environment.sdk` / `environment.flutter` も同じバージョンに
演算子なしの完全一致で固定している。

そのため、Flutterのバージョンを上げる際は `mise.toml` だけでなく
`pubspec.yaml` 側も合わせて更新する必要がある。片方だけを更新すると、
`mise` が解決するFlutterのバージョンと `pubspec.yaml` の制約が食い違い、
`flutter pub get` がSDKバージョン不一致で失敗する。

## 手順

1. `mise.toml` の `tools.flutter` を新しいバージョンに更新する。
2. `mise install` を実行し、指定したバージョンのFlutterを導入する。
3. `mise exec -- flutter --version` で導入されたFlutter/Dartのバージョンを確認する。
4. `pubspec.yaml` の `environment.sdk` / `environment.flutter` を、
   手順3で確認したバージョンに合わせて更新する。
5. `mise exec -- flutter pub get` を実行し、`pubspec.lock` の `sdks` が
   更新後のバージョンで一致して解決されることを確認する。
6. `mise exec -- flutter analyze` / `flutter test` を実行し、
   アップグレードに伴う問題が無いことを確認する。
7. `pubspec.yaml` / `pubspec.lock` の差分を含めてコミットする。
