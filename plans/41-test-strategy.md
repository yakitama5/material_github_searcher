# Issue #41 テスト戦略とテスト実装ルールを定義

## 目的

機能実装に先立ち、本プロジェクトにおけるテストの役割、配置、実装方針、実行方法を
プロジェクトルールとして定義する。ゆめみの Flutter エンジニアコードチェック課題の
評価観点を踏まえ、Unit Test・Widget Test・Golden Test・E2E Test を過不足なく
使い分けられる状態にする。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/41>

## 調査結果

- 現状はまだ Flutter のスターターテンプレート段階で、`packages/domain` などの
  中身は空の library 宣言のみ。状態管理ライブラリ（Riverpod 等）は未選定で、
  `pubspec.yaml` にも riverpod 系の依存は存在しない。
- 既存のテストは `apps/app/test/widget_test.dart`、
  `apps/app/test/config/app_build_config_test.dart`、
  `test/tools/*_test.dart`（`tools/` 配下スクリプトのシナリオテスト）のみ。
- `docs/ARCHITECTURE.md` はパッケージ構成と依存方向、`packages/infrastructure/mock`
  が決定的な Fake/Mock の置き場になる想定を既に定義している。
- `.github/workflows/check_pr.yaml` は Required Status Check として
  Format・Analyze・Test・Package Dependencies・cspell・Markdown Lint を集約しており、
  冒頭のコメントで「Build と Patrol は実行時間・安定性の観点から対象外」と明記済み。
  つまり「CI = 高速で決定的なテスト、ローカル = Patrol E2E」という境界は
  既に運用上の決定として存在し、今回のドキュメントはこれを追認し明文化する。
- `test` ジョブは現状 `dart test test/tools` と `apps/app` の `flutter test` のみを
  実行しており、`packages/*` に `test/` が無いため個別には何も実行していない。
  `docs/ARCHITECTURE.md` は「複数パッケージのテストが必要になった時点で Melos 導入等を
  再検討する」としており、本 Issue はその判断を前倒ししない。
- 参考として作者の別リポジトリ `flutter-layer-template` の
  `.agents/common/testing.md` を確認した。Melos の `melos run test:ci` /
  `test:golden` を前提にした実行コマンド体系や、golden test に alchemist を使う
  想定などが含まれるが、本リポジトリは Melos を採用しない方針
  （`docs/ARCHITECTURE.md`）のため、実行コマンド部分はそのまま転用せず、
  本リポジトリの実コマンド（`flutter test` / `dart test` を各パッケージで直接実行）に
  置き換える。

## 実装方針

### スコープの線引き

Issue の完了条件（テスト戦略の文書化、レイヤー別責務、ローカル/CI境界、Golden/Patrol
の位置付け、今後のテスト追加基準、Markdown Lint/cspell 通過）を満たすことに専念し、
対象外に明記された次を行わない。

- Golden Test 基盤（alchemist 等）の導入、`pubspec.yaml` へのテスト用依存追加
- Patrol 基盤の導入
- 個別機能のテスト実装
- CI Workflow (`check_pr.yaml` 等) の変更

Golden Test・Patrol は「役割・置き場所・使い分けの基準」を記述し、
「現時点では基盤未導入であり、導入は別 Issue で行う」ことを明記する。

### ドキュメント構成

`docs/testing.md` を新規作成し、次の構成で記述する。各見出しは Issue の完了条件と
1:1 で対応させ、条件の記載漏れを防ぐ。

1. 基本方針（何を・どこまでテストするか、変更した振る舞いをテストする原則、
   一律のカバレッジ目標を設けない方針）
2. レイヤー別のテスト責務（`docs/ARCHITECTURE.md` のパッケージ表に対応させる）
   - domain: 値オブジェクト・業務ルールの Unit Test
   - application: UseCase・Provider のテスト（`dependency_override` と同様に
     Fake を注入する想定。状態管理ライブラリは未選定のため、実装方法は決定次第
     追記する前提を明記する）
   - designsystem: Widget Test・Golden Test
   - app: 画面・ルーティングの Widget Test
   - 主要ユーザーフロー: Patrol によるローカル E2E Test
3. 配置・命名規約（`test/` はパッケージ直下、対象コードと対称なパス、
   `_test.dart` 命名）
4. Fake/Mock の方針（外部サービスへ直接接続せず決定的な Fake に差し替える、
   再利用可能な Fake は `packages/infrastructure/mock` に集約し、
   application 層限定の最小 Fake はテストファイル内に閉じてよい）
5. 実行方法とローカル/CI の境界（`docs/development.md` の実コマンドを引用し、
   CI は Unit/Widget/Golden など高速で決定的なテストのみ、Patrol はローカル実行。
   `check_pr.yaml` の既存コメントを根拠として明記）
6. Golden Test と Patrol の位置付け（役割、導入予定であり本 Issue では未導入である旨、
   導入後に本ドキュメントを更新する前提）
7. 不具合修正時の再現テスト方針
8. 今後の機能 PR で参照するテスト追加基準（新規ロジックは domain/application で
   Unit Test、新規 Widget は designsystem/app で Widget Test、主要フロー変更は
   Patrol シナリオ追加を検討、という判断基準）

### 参照の追加

`AGENTS.md`（実体は `.agents/AGENTS.md`）の「定義」一覧に
`テスト戦略: docs/testing.md` を追加し、将来の機能 PR から参照できるようにする。

### 表記ゆれ・cspell 対応

`patrol`、`alchemist`、`goldens` など、`.cspell/project-term.txt` に未登録の
英単語を使う場合は追加する。

## 実装手順

1. `docs/testing.md` を新規作成する。
2. `.agents/AGENTS.md` の「定義」に `docs/testing.md` への参照を追加する。
3. 新規英単語があれば `.cspell/project-term.txt` に追加する。
4. `npx markdownlint-cli2 docs/testing.md .agents/AGENTS.md` と
   `npx cspell docs/testing.md .agents/AGENTS.md` を実行し、通過を確認する。
5. Draft PR を作成する。

## 品質ゲート

- Markdown Lint (`markdownlint-cli2`) が新規・更新ファイルに対して成功する。
- cspell が新規・更新ファイルに対して成功する。
- Issue の完了条件 6 項目すべてに対応する記述がドキュメント内に存在する。
- Melos や未導入ツールの実行コマンドなど、本リポジトリの実態と矛盾する記述がない。

## リスクと対応

- 状態管理ライブラリ未選定のまま application 層のテスト方針を書くと、選定後に
  矛盾が出る可能性がある。実装方法の詳細（Provider の書き方など）には踏み込まず、
  「Fake を注入してテストする」という抽象度に留め、選定後の追記を前提として明記する。
- 参考にした `flutter-layer-template` の Melos 前提の記述をそのまま転記すると、
  本リポジトリの `docs/ARCHITECTURE.md` の方針（Melos 不採用）と矛盾するため、
  実行コマンドは本リポジトリの実コマンドに置き換える。
