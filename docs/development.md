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
Android では `--flavor` の指定も必須で、Dev/Prod でアプリ名・Application ID が
切り替わり、同一端末へ同時インストールできる。

```sh
cd apps/app

# Dev (Android)
mise exec -- flutter run --flavor dev --dart-define-from-file=flavor/dev.json

# Prod (Android)
mise exec -- flutter run --flavor prod --dart-define-from-file=flavor/prod.json

# Dev (Web など Android 以外)
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
```

## Flutterのアップグレード

手順は [`flutter-upgrade.md`](flutter-upgrade.md) を参照。
