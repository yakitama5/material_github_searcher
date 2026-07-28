# material_github_searcher

A new Flutter project.

## 開発環境のセットアップ

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

Flutterアプリの実行、テスト、buildは `apps/app` で行う。
実行時は Dev または Prod の Flavor 設定ファイルを必ず指定する。

```sh
cd apps/app
# Dev
mise exec -- flutter run --dart-define-from-file=flavor/dev.json

# Prod
mise exec -- flutter run --dart-define-from-file=flavor/prod.json

mise exec -- flutter test

# Dev の Web build
mise exec -- flutter build web --dart-define-from-file=flavor/dev.json

# Prod の Web build
mise exec -- flutter build web --dart-define-from-file=flavor/prod.json
```

VS Code では Run and Debug から `Dev` または `Prod` を選択する。
IntelliJ IDEA / Android Studio では Run Configuration から `Dev` または `Prod` を
選択する。いずれも対応する `apps/app/flavor/*.json` を読み込む。

Flutterのバージョンをアップグレードする際の手順は
[`docs/flutter-upgrade.md`](docs/flutter-upgrade.md) を参照。

## Workspace構成

- `apps/app`: Flutterアプリ
- `packages/`: アーキテクチャレイヤーごとのパッケージ
- `tools/sync_sdk_versions.dart`: `mise.toml` から全パッケージへSDK制約を同期するツール

パッケージの責務と依存方向は [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) を参照。

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
