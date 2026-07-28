# Issue #51 高速な検査を集約した必須PR Checkerを追加

## 目的

PRで必ず通過すべき高速かつ決定的な品質検査を1つの `Check PR` Workflowへ集約し、
Branch protectionのRequired Status Checkとして設定する。BuildとPatrolは実行時間・
安定性の観点から対象外とする。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/51>

## 前提との差分（調査結果）

- Issue本文はFormat / Analyze / Unit Test / Widget Test / Golden Test /
  Package Dependencies / cspell / Markdown Lintの集約を求めているが、
  現状のリポジトリには以下の差分がある。
  - **Format**: 専用のCIジョブが存在しない。`dart format --output=none
    --set-exit-if-changed` を新規に追加する。
  - **Unit / Widget / Golden Testの分離**: 現状は `flutter test`
    （`apps/app/test/`）と `dart test test/tools` を一括実行するのみで、
    テスト種別ごとにジョブやディレクトリを分離する基盤は存在しない。
    Golden Testの実装（ゴールデンファイル・テストコード）も0件。
    Issueの前提「CI対象のUnit / Widget / Golden Test基盤が利用可能で
    あること」は満たされていないため、本Issueでは既存の `flutter test` /
    `dart test test/tools` をそのまま「Test」ジョブとして集約するに留め、
    テスト種別の分離自体は別Issueとする。

## 集約方式（単一ファイル vs reusable workflow）

`docs/ARCHITECTURE.md` には「CIワークフローはチェック内容ごとに専用ファイルへ
分ける。並列開発時のファイル競合を避けるため、複数のチェックを単一ファイルへ
集約しない」という明記された方針がある（#38で導入、`git gtr` によるworktree
並列開発を想定した取り決め）。

Issue #51は参考実装
（<https://github.com/yakitama5/flutter-layer-template/blob/main/.github/workflows/check_pr.yaml>）
の通り単一ファイルでの集約を想定しており、字面上はARCHITECTURE.mdの方針と
矛盾する。検討の結果、**単一ファイル方式を採用**する。

- Issue #51はどのみち集約用の中心ファイル（Required Status Checkの対象）を
  要求しており、reusable workflow方式でも「各専用workflowにworkflow_call
  inputsを追加し、単独トリガーを外す」という形で6ファイル全てに手を入れる
  ことになり、変更範囲は単一ファイル化とさほど変わらない。
- 集約Status Checkの判定ロジック（skipは許容するが判定失敗はfailにする、
  など）は複数ファイルにinputsを跨がせるより1ファイルに閉じたほうが正しく
  書きやすく、レビューもしやすい。
- `check_pr.yaml` が並列ブランチ間の衝突ポイントになり得るが、単一ファイルの
  変更頻度は低く、コンフリクトが起きても解消は容易なため許容する。

この判断に伴い、ARCHITECTURE.mdの方針記述を「Check PRという集約Workflowに
限り、複数チェックの単一ファイル集約を許容する」旨の理由付きで書き換える。

## 実装方針

### ワークフロー構成

- `.github/workflows/check_pr.yaml` を新規作成する。
- `on: pull_request (opened, synchronize, reopened)` と `on: push (main)`
  で起動する。
- 最初に `detect_ci_changes.yaml` を1回だけ呼び出す（`changes` job）。
- 各チェックはこの `changes` jobの出力を条件に実行するジョブとして
  `check_pr.yaml` 内に直接定義する。
  - `format`: `dart format --output=none --set-exit-if-changed`
  - `analyze`: 既存 `analyze.yaml` の内容を移植
  - `test`: 既存 `test.yaml` の内容を移植
  - `check_package_dependencies`: 既存 `check_package_dependencies.yaml`
    の内容を移植
  - `cspell`: 既存 `cspell.yaml` の内容を移植
  - `markdown_lint`: 既存 `markdown_lint.yaml` の内容を移植
- 既存の `analyze.yaml` / `test.yaml` / `cspell.yaml` / `markdown_lint.yaml`
  / `check_package_dependencies.yaml` は削除する。
- `detect_ci_changes.yaml` に `format` の出力を追加する（Analyzeと同じDart
  対象パスで判定）。`.github/scripts/detect_ci_changes.sh` と
  `test_detect_ci_changes.sh` を合わせて更新する。

### 集約Status Checkジョブ

- `status-check` ジョブは `changes` job含む全ジョブを `needs` にし、
  `if: always()` で必ず実行する。
- 判定ロジック（完了条件の全項目を満たす）:
  1. `needs.changes.result != 'success'` の場合は必ずfail
     （変更パス判定自体の失敗・キャンセルを、実処理ジョブのskipとして
     誤認しない）。
  2. 各実処理ジョブの結果が `failure` または `cancelled` の場合はfail。
  3. `skipped` は許容する（参考実装の
     `contains(needs.*.result, 'skipped') → fail` はコピーしない。
     これは完了条件「不要なジョブのskipだけでは集約Status Checkが
     失敗しない」に反するため）。
- Required Status Checkには `status-check` ジョブのみを設定する。
  Required Checkが未実行のまま待機しないよう、`check_pr.yaml` は全PRで
  必ず起動し、`status-check` は `always()` で必ず結果を返す。

### Branch protection

- GitHub側のBranch protectionルールで、`status-check`
  （`Check PR / status-check` 相当）をRequired Status Checkに追加する。

## 品質ゲート

- `bash -n` によるシェル構文チェック
- `test_detect_ci_changes.sh` の全シナリオがパスすること
- YAML構文チェック（`actionlint` 等が利用可能であれば使用）
- 完了条件9項目それぞれについて、想定シナリオでの集約Status Checkの
  成否を机上で確認する
