# Issue #49 CI の変更パス判定と実行対象を整理

## 目的

Pull Request では変更の影響を受ける CI ジョブだけを実行し、ドキュメント変更などで
Flutter のセットアップ、静的解析、テストを不要に実行しないようにする。一方で、
`main` への push では現在の安全網を維持し、全 CI を実行する。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/49>

## 調査結果

- Analyze、Test、cspell、Package Dependencies は、Pull Request と `main` push の
  すべてで無条件に実行されている。
- Markdown Lint だけは Workflow の `paths` フィルターで実行を絞っている。
- Workflow 自体を `paths` で起動しない構成は、後続の必須 PR Checker から見ると
  「成功」ではなく「Workflow が存在しない」状態になる。このため、イベントは受け、
  共通判定の結果で実処理ジョブを skip する構成が適している。
- Flutter を利用する Analyze、Test、Package Dependencies は
  `.github/actions/setup-flutter/action.yaml` と `mise.toml` の影響も受ける。
- cspell の対象拡張子と除外は `cspell.jsonc`、Markdown Lint の対象は Markdown と
  `.markdownlint-cli2.jsonc` で定義されている。

## 実装方針

### 共通の変更判定

変更ファイル一覧を分類するシェルスクリプトを `.github/scripts/` に配置する。
分類結果は `analyze`、`test`、`cspell`、`markdown_lint`、
`package_dependencies` の boolean とし、GitHub Actions の job output にできる形式で
出力する。

このスクリプトを呼び出す reusable workflow を用意し、各 CI Workflow は最初の job
として呼び出す。実処理 job は対応 output が `true` の場合だけ実行する。後続の
PR Checker も同じ reusable workflow または分類スクリプトを再利用できる。

### パス分類

- Analyze: Dart、pubspec、lockfile、解析設定、Flavor の dart-define JSON、SDK 設定
- Test: Dart（テストを含む）、pubspec、lockfile、Flavor の dart-define JSON、SDK 設定
- Package Dependencies: pubspec、lockfile、`tools/` 配下の依存関係検査・SDK 同期の
  実装と、`test/tools/` 配下の Dart テスト
- cspell: cspell が検査する Markdown、YAML、Dart、および辞書・設定
- Markdown Lint: Markdown と Markdown Lint 設定
- 各 CI Workflow 自身: 対応する分類
- 共通変更判定、reusable workflow: 全分類
- Flutter セットアップ用 composite action: Analyze、Test、Package Dependencies

### `main` push の方針

`main` push では差分にかかわらず共通判定の全 output を `true` にする。Analyze、Test、
cspell、Package Dependencies は従来の無条件実行を維持する。従来パス制限があった
Markdown Lint は、PR で見落とした組み合わせも統合後に検出する安全網として、
`main` push では全実行へ拡張する。Pull Request のときだけ merge-base から head
までの変更ファイルを分類する。

## 実装手順

1. 変更ファイル一覧を CI ごとに分類するスクリプトを追加する。
2. `main` push の全実行と Pull Request の差分取得を担当する reusable workflow を
   追加する。
3. Analyze、Test、cspell、Markdown Lint、Package Dependencies から共通 Workflow を
   呼び、実処理 job に条件を追加する。
4. 分類スクリプトのシナリオテストを追加する。
5. GitHub Actions の YAML 構文、シェル構文、代表パスの実行・skip 判定を検証する。

## 品質ゲート

- Markdown のみ: Markdown Lint と cspell が `true`、Flutter 系 CI が `false`
- Dart: Analyze、Test、cspell が `true`
- `apps/app/flavor/*.json`: Analyze、Test が `true`
- pubspec / lockfile: Analyze、Test、Package Dependencies が `true`
- 依存関係検査コード: Analyze、Test、Package Dependencies が `true`
- 各 Workflow: 対応 CI が `true`
- 共通判定: 全 CI が `true`
- `main` push: 全 CI job が条件にかかわらず実行対象
- `bash -n`、分類スクリプトのテスト、YAML parser、`git diff --check` が成功

## リスクと対応

- shallow clone では merge-base を参照できないため、変更判定 job の checkout は
  `fetch-depth: 0` とする。
- GitHub Actions の式で boolean と文字列を混同しないよう、outputs は `true` / `false`
  の文字列に統一し、呼び出し側は `== 'true'` で比較する。
- 共通判定自身の変更を見落とすと CI が誤って skip されるため、共通 Workflow と
  スクリプトの変更は全分類を `true` にする。
