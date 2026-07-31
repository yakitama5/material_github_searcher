# よく使う開発コマンド（Darwin/macOS）

前提: Flutter/Dartのバージョンは`mise`で固定（`mise install`必須）。コマンドは基本`mise exec --`経由。

## セットアップ・依存関係
```sh
mise install
mise exec -- dart tools/sync_sdk_versions.dart --check   # mise.tomlとの不一致検出
mise exec -- flutter pub get                             # リポジトリルートで一括解決
```

## SDKバージョン同期（mise.tomlが唯一の正）
```sh
mise exec -- dart tools/sync_sdk_versions.dart
```

## アーキテクチャ依存方向チェック
```sh
dart run tools/check_package_dependencies.dart
```

## 多言語化（slang）コード生成
```sh
mise exec -- dart run build_runner build --workspace -d   # apps/appへcdする必要なし
```

## Lint / Format
```sh
dart format --output=none --set-exit-if-changed apps packages test tools   # CIと同じformatチェック
dart analyze --fatal-infos                                                  # infoレベルも検知（CIと同じ）
```

## テスト
```sh
# 純粋なDartパッケージ（domain等）
cd packages/domain && mise exec -- dart test

# Flutterパッケージ・アプリ（apps/app, designsystem等）
cd apps/app && mise exec -- flutter test

# designsystemのGolden Test（CI対象外、コミット前に必須）
cd packages/designsystem
flutter test --exclude-tags=golden   # 通常のWidget/Unit Test
flutter test --tags=golden           # Golden Testのみ
flutter test --tags=golden --update-goldens  # 見た目変更時の更新
```

## アプリの実行（`apps/app`で実行、Flavor指定必須）
```sh
cd apps/app
mise exec -- flutter run --flavor dev --dart-define-from-file=flavor/dev.json
mise exec -- flutter run --flavor prod --dart-define-from-file=flavor/prod.json
```

## E2E Test（Patrol、ローカルのみ、CI対象外）
```sh
mise run test:e2e <Android device ID または iOS Simulator ID>
```

## Git / PR
- `git gtr new <branch>` / `git gtr ai <branch>` / `git gtr rm <branch>`（複数エージェント並列開発用のgit worktree runner）
- コミット規約: `.agents/skills/commit-changes/SKILL.md`
- PRレビューレポート: `.agents/skills/pr-review-report/SKILL.md`
