# プロジェクト概要

## 目的
`material_github_searcher` は Flutter 製の GitHub リポジトリ検索アプリ。Material Design 3 (MD3) 準拠のUIを持つ。

## 技術スタック
- 言語/SDK: Dart 3.12.2 / Flutter 3.44.8（`mise.toml` で固定管理）
- パッケージ管理: Dart標準の Pub Workspace（Melosは不使用）
- 状態管理: Riverpod（`packages/application` は generator を使わず手書きProvider、`package:riverpod`のみに依存。Flutter Widget側の `apps/app` だけが `package:flutter_riverpod` を利用）
- Lint: `altive_lints`（`analysis_options.yaml` から include、`dart analyze --fatal-infos` で info レベルも検知）
- 多言語化: `slang` / `slang_flutter`（日本語・英語、`apps/app/assets/i18n/*.i18n.yaml`）
- E2E: Patrol（Android実機 / iOS Simulatorのみ、CI対象外）
- Golden Test: alchemist（CI対象外、コミット前にローカル実行必須）

## Workspace構成（ディレクトリ）
- `apps/app`: Flutterアプリ本体（画面、ルーティング、ローカライズ、composition root）
- `packages/domain`: エンティティ、値オブジェクト、リポジトリ抽象、業務ルール（Flutter/外部I/O非依存）
- `packages/application`: ユースケース、アプリ状態、Provider（Flutter非依存）
- `packages/infrastructure/github`, `packages/infrastructure/mock`, `packages/infrastructure/shared_preferences`: リポジトリ実装（外部サービス・永続化）
- `packages/designsystem`: テーマ、共通Widget（MD3準拠・レスポンシブ）
- `packages/dependency_override`: application の Provider と infrastructure 実装の結線（composition rootが利用）
- `packages/foundation`: ロガー等、ドメイン非依存の純粋ユーティリティ
- `tools/sync_sdk_versions.dart`: `mise.toml` を正としてSDKバージョンを全パッケージへ同期
- `tools/check_package_dependencies.dart`: アーキテクチャ依存方向の機械的検査
- `docs/`: ARCHITECTURE.md（アーキテクチャ）, testing.md（テスト戦略）, development.md（開発コマンド）, design.md（デザイン方針）, branching.md（ブランチ戦略）, technical-decisions.md（技術選定の経緯）

## ブランチ戦略
GitHub Flow採用（`develop`なし）。`main`から都度ブランチを切り、Squash mergeでマージ。マージ後ブランチは自動削除。

詳細は [[architecture_and_conventions]] [[suggested_commands]] [[task_completion_checklist]] を参照。
