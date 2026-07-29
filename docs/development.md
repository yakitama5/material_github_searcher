# 開発ガイド

このリポジトリでの開発コマンドをまとめる。

## セットアップ

このリポジトリでは [mise](https://mise.jdx.dev/) でFlutterのバージョンを固定管理している。
開発者間・CI間でのバージョン差異を防ぐため、`mise.toml` に記載されたバージョンを使用すること。

```sh
mise install
```

実行後、`flutter --version` で `mise.toml` の `flutter` に指定したバージョンが
解決されていることを確認する。

依存関係はリポジトリルートで一括解決する。

```sh
mise exec -- dart tools/sync_sdk_versions.dart --check
mise exec -- flutter pub get
```

## 多言語化（slang）のコード生成

`apps/app` は `slang`/`slang_flutter` で日本語・英語の文言を管理する。設定は
`apps/app/build.yaml`、翻訳リソースは `apps/app/assets/i18n/*.i18n.yaml` に置く。
`build_runner` の `--workspace` フラグにより、リポジトリルートから次のコマンドで
生成できる（`apps/app` へ `cd` する必要はない）。

```sh
mise exec -- dart run build_runner build --workspace -d
```

生成された `apps/app/lib/i18n/*.g.dart` はリポジトリにコミットする。翻訳
リソースを変更したら、コミット前に上記コマンドで再生成すること。

## アプリの実行・テスト・build

Flutterアプリの実行、テスト、buildは `apps/app` で行う。
実行時は Dev または Prod の Flavor 設定ファイルを必ず指定する。
Android/iOS では `--flavor` の指定も必須で、Dev/Prod でアプリ名・
Application ID（iOSはBundle ID）が切り替わり、同一端末または
Simulatorへ同時インストールできる。

```sh
cd apps/app

# Dev (Android)
mise exec -- flutter run --flavor dev --dart-define-from-file=flavor/dev.json

# Prod (Android)
mise exec -- flutter run --flavor prod --dart-define-from-file=flavor/prod.json

# Dev (iOS Simulator)
mise exec -- flutter run --flavor dev --dart-define-from-file=flavor/dev.json -d <Simulator ID>

# Prod (iOS Simulator)
mise exec -- flutter run --flavor prod --dart-define-from-file=flavor/prod.json -d <Simulator ID>

# Dev (Web など Android/iOS 以外)
mise exec -- flutter run --dart-define-from-file=flavor/dev.json

mise exec -- flutter test

# Dev の Web build
mise exec -- flutter build web --dart-define-from-file=flavor/dev.json

# Prod の Web build
mise exec -- flutter build web --dart-define-from-file=flavor/prod.json

# Dev の Android Debug build
mise exec -- flutter build apk --flavor dev --debug --dart-define-from-file=flavor/dev.json

# Prod の Android Debug build
mise exec -- flutter build apk --flavor prod --debug --dart-define-from-file=flavor/prod.json

# Dev の iOS Simulator build
mise exec -- flutter build ios --flavor dev --debug --simulator --dart-define-from-file=flavor/dev.json

# Prod の iOS Simulator build
mise exec -- flutter build ios --flavor prod --debug --simulator --dart-define-from-file=flavor/prod.json
```

iOSの `-d <Simulator ID>` は `xcrun simctl list devices` または `flutter devices` で
確認した起動中Simulatorの識別子に置き換える。

iOSはFlutterの `--flavor` 名（`dev`/`prod`）と同名の共有Scheme
（`ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme` / `prod.xcscheme`）で
Build Configuration（`Debug-dev`/`Release-dev`/`Profile-dev` など）を切り替えている。
Xcodeを直接開いて実行する場合も、無印の `Runner` Schemeではなく `dev`/`prod` Scheme を
選択すること（無印Schemeは Flavor の dart-define が渡らず起動時エラーになる）。

Bundle IDやアプリ名（`PRODUCT_BUNDLE_IDENTIFIER` / `APP_DISPLAY_NAME`）は
`apps/app/flavor/dev.json` / `prod.json` を唯一のソースとして解決される。
`ios/scripts/extract_dart_defines.sh` が `dev`/`prod` Scheme のBuild Pre-actionとして
実行され、`--dart-define-from-file` の内容（`DART_DEFINES`）をデコードして
`ios/Flutter/Environment.xcconfig`（gitignore対象、都度生成）へ書き出し、
`Debug-<flavor>`/`Release-<flavor>`/`Profile-<flavor>` の
`PRODUCT_BUNDLE_IDENTIFIER = "$(appIdIos)$(appIdSuffix)"` /
`APP_DISPLAY_NAME = "$(appName)"` がそれを参照する。Androidの
`build.gradle.kts`（`flavor/*.json` を直接読み取り）と同様、flavor設定ファイルの
値を変更するだけでiOS側にも反映され、pbxprojへの追随修正は不要。
無印の `Debug`/`Release`/`Profile`（既存の `Runner` Scheme用）はこの仕組みの
対象外で、従来どおりの固定値のまま変更していない。

## Flutterのアップグレード

手順は [`flutter-upgrade.md`](flutter-upgrade.md) を参照。
