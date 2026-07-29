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

Bundle IDやアプリ名の切り替え値（`PRODUCT_BUNDLE_IDENTIFIER` / `APP_DISPLAY_NAME`）は
`apps/app/flavor/dev.json` / `prod.json` の値を `project.pbxproj` 側にも複製している。
AndroidはGradleから `flavor/*.json` を直接読み取り単一ソース化しているが、Xcodeの
Build Configurationは静的な値しか持てないため、iOSでは値を複製する方式を採っている。
Flavor設定ファイルの `appName` / `appIdIos` / `appIdSuffix` を変更した場合は、
`project.pbxproj` 内の対応する `Debug-<flavor>` / `Release-<flavor>` / `Profile-<flavor>`
設定も合わせて更新すること。

## Flutterのアップグレード

手順は [`flutter-upgrade.md`](flutter-upgrade.md) を参照。
