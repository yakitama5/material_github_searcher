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

```sh
cd apps/app
mise exec -- flutter run
mise exec -- flutter test
mise exec -- flutter build web
```

Flutterのバージョンをアップグレードする際の手順は
[`docs/flutter-upgrade.md`](docs/flutter-upgrade.md) を参照。

## Workspace構成

- `apps/app`: Flutterアプリ
- `packages/`: アーキテクチャレイヤーごとのパッケージ
- `tools/sync_sdk_versions.dart`: `mise.toml` から全パッケージへSDK制約を同期するツール

パッケージの責務と依存方向は [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) を参照。

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
