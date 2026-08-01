# material_github_searcher

A new Flutter project.

## 対応プラットフォーム

Android/iOSを正式対象とする。Webは正式配布対象ではなく、Device Previewや
ローカル動作確認用に維持する。Windows・macOS・Linux runnerは意図的に削除した
（詳細は[`docs/development.md`](docs/development.md)を参照）。

## 開発

開発環境のセットアップ、アプリの実行・テスト・buildコマンドは
[`docs/development.md`](docs/development.md) を参照。

## Workspace構成

- `apps/app`: Flutterアプリ
- `packages/`: アーキテクチャレイヤーごとのパッケージ
- `tools/sync_sdk_versions.dart`: `mise.toml` から全パッケージへSDK制約を同期するツール

パッケージの責務と依存方向は [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) を参照。

技術選定・不選定の理由と背景は
[`docs/technical-decisions.md`](docs/technical-decisions.md) を参照。

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
