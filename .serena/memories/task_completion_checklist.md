# タスク完了時に確認すること

コード変更後、コミット前に以下を確認する（CI = `.github/workflows/check_pr.yaml`）。

1. **Format**: `dart format --output=none --set-exit-if-changed apps packages test tools` が差分なしで通ること。
2. **Analyze**: `dart analyze --fatal-infos` が警告0件で通ること（altive_lintsはinfoレベル中心なので`--fatal-infos`必須）。
3. **SDKバージョン整合**: `pubspec.yaml`のSDK制約を手で変更した場合は`mise exec -- dart tools/sync_sdk_versions.dart --check`で`mise.toml`との一致を確認。手作業で各pubspec.yamlを更新しない。
4. **アーキテクチャ依存方向**: パッケージ間のimportを追加/変更した場合は`dart run tools/check_package_dependencies.dart`で許可されていない依存が無いか確認。
5. **テスト**: 変更した振る舞いに対応するテストを追加/更新し、対象パッケージで`dart test`または`flutter test`を実行。
   - `domain`/`application`: Unit Test
   - `designsystem`/`apps/app`: Widget Test（見た目の回帰が懸念される共通WidgetはGolden Testも検討）
   - 不具合修正: 再現テストを先に追加し、修正後に通ることを確認
6. **Golden Test**（`packages/designsystem`のWidgetを変更した場合のみ、CI対象外・ローカル必須）:
   `flutter test --tags=golden`を実行し、意図しない見た目変化が無いか確認。意図的な変更時は`--update-goldens`し、生成画像を目視確認してからコミット。PRの説明に実行結果を明記する。
7. **i18n（slang）**: 翻訳リソース（`apps/app/assets/i18n/*.i18n.yaml`）を変更した場合、`mise exec -- dart run build_runner build --workspace -d`で再生成し、生成された`*.g.dart`もコミットする。日本語・英語両方の表示を検証するWidget Testを追加する。
8. **Patrol E2E**（主要ユーザーフローに影響する変更の場合）: ローカルで`mise run test:e2e <device ID>`を検討（CI対象外）。

CIの`test`ジョブは現状`test/tools`、`packages/application`、`packages/designsystem`、`apps/app`のみを対象とする。`packages/domain`等に`test/`を新設した場合はCI設定への追加も検討する。

コミット手順は`.agents/skills/commit-changes/SKILL.md`に従う。
