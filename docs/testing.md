# テスト戦略

<!-- cspell:words designsystem alchemist goldens -->

本ドキュメントは、本プロジェクトにおけるテストの役割・配置・実装方針・実行方法を
定義する。機能実装の前に読み、追加するテストの種類と置き場所を判断する材料とする。

## 基本方針

- **変更した振る舞いをテストすることを原則とする。** 一律のカバレッジ数値目標は
  当面設けない。数値目標だけを追う形骸化したテストより、仕様変更や不具合修正に
  対応したテストの積み重ねを優先する。
- テストの種類は `docs/ARCHITECTURE.md` のレイヤー構成に対応させる。内側の
  レイヤー（`domain`、`application`）ほど純粋なロジックの Unit Test で検証し、
  外側のレイヤー（`designsystem`、`app`）ほど画面・操作を含む Widget Test で
  検証する。
- 外部サービス（GitHub API など）へ直接接続するテストは書かない。
  `packages/infrastructure/*` の抽象を、決定的な Fake/Mock に差し替えて検証する。
- 不具合を修正する際は、原則としてその不具合を再現するテストを先に追加し、
  修正後にテストが通ることを確認する。再現テストは該当レイヤーの `test/` に残し、
  リグレッションの防止に使う。

## レイヤー別のテスト責務

`docs/ARCHITECTURE.md` のパッケージ構成に対応させ、各レイヤーで書くテストの種類を
次のとおり定義する。

| パッケージ | テスト種別 | 検証内容 |
| --- | --- | --- |
| `packages/domain` | Unit Test | 値オブジェクトの不変条件、業務ルールの純粋なロジック |
| `packages/application` | Unit Test | UseCase・Provider の振る舞い。`domain` の抽象を Fake に差し替えて検証する |
| `packages/infrastructure/*` | Unit Test | リポジトリ実装の入出力変換。実サービスへは接続しない |
| `packages/designsystem` | Widget Test / Golden Test | 共通 Widget の表示・操作。見た目の回帰は Golden Test で検証する |
| `apps/app` | Widget Test | 画面の表示、ユーザー操作（tap 等）、ルーティング |
| 主要ユーザーフロー | E2E Test（Patrol） | 複数画面をまたぐ実利用シナリオ |

`packages/application` は状態管理の実装方法を本ドキュメント執筆時点で未選定のため、
「`domain` の抽象を Fake に差し替えて UseCase・Provider を検証する」という抽象度に
留める。具体的な実装パターン（Provider の書き方など）は、状態管理ライブラリの選定後に
本ドキュメントへ追記する。

## 配置と命名規約

- テストは対象コードと同じパッケージの `test/` 配下に置き、対象コードのパスと
  対称になるディレクトリ構成にする（例: `lib/src/config/app_build_config.dart` に対して
  `test/config/app_build_config_test.dart`）。
- テストファイル名は対象ファイル名に `_test.dart` を付けた名前にする。
- `tools/` 配下のスクリプトに対するテストは、対象パッケージを持たないため
  リポジトリ直下の `test/tools/` に置く（既存の `sync_sdk_versions_test.dart` などを
  踏襲する）。

## Fake/Mock の方針

- 外部サービスへ直接接続するテストは書かず、`domain` に定義したリポジトリ抽象を
  決定的な Fake に差し替える。
- 複数のテストから再利用する Fake は `packages/infrastructure/mock`
  （`infrastructure_mock`）に集約し、`application` のテストや将来の E2E から
  参照できるようにする。`docs/ARCHITECTURE.md` が定義する依存性逆転の構成と
  一致させ、`infrastructure_mock` 以外のレイヤーが実サービスの詳細を意識しない
  ようにする。
- `application` 層のテストだけで使う最小限の Fake は、依存関係を増やさないために
  テストファイル内に閉じて定義してよい。他のテストから再利用する必要が出た時点で
  `packages/infrastructure/mock` へ移動する。

## 実行方法とローカル/CI の境界

コマンドは `docs/development.md` の実行環境を前提とする。

```sh
# 純粋な Dart パッケージ（domain 等、Flutter に依存しないパッケージ）
cd packages/domain
mise exec -- dart test

# Flutter パッケージ・アプリ（apps/app、designsystem 等）
cd apps/app
mise exec -- flutter test
```

CI（`.github/workflows/check_pr.yaml`）は、実行時間・安定性の観点から Unit Test・
Widget Test・Golden Test など高速かつ決定的なテストのみを対象にする。Patrol による
E2E Test は Required Status Check に含めず、ローカルで実行する。この境界は
`check_pr.yaml` 冒頭のコメント（「Build と Patrol は実行時間・安定性の観点から対象外」）
で既に運用上の決定として明文化されており、本ドキュメントはこれを踏襲する。

現状の `test` ジョブは `test/tools` と `apps/app` の `flutter test` のみを実行して
おり、`packages/domain` 等に `test/` を追加した時点で、それらも CI 対象に含める
必要がある。パッケージ横断でテストを一括実行する仕組み（Melos 等）は、
`docs/ARCHITECTURE.md` が定義するとおり複数パッケージのテストが実際に必要になった
段階で再検討する。現時点ではパッケージごとに `dart test` / `flutter test` を
直接実行する。

## Golden Test と Patrol の位置付け

- **Golden Test**: `packages/designsystem` の共通 Widget や、`apps/app` の
  主要画面の見た目の回帰を検出する。ロジックではなく描画結果の変化を検知する
  目的に限定し、頻繁に変化するレイアウトには適用しない。
- **Patrol**: 実機・エミュレータ上で複数画面をまたぐ主要ユーザーフロー
  （例: 検索してリポジトリ詳細を開く）を検証する E2E Test。外部サービスへの
  依存は `dependency_override` で決定的な Fake に差し替えたうえで実行する想定とする。
- Golden Test・Patrol とも、本ドキュメント執筆時点では基盤（Golden Test 用ライブラリ、
  Patrol のセットアップ）を導入していない。基盤導入は別 Issue で行い、導入後に
  実行コマンドとディレクトリ構成を本ドキュメントへ追記する。

## テスト追加基準（今後の機能 PR 向け）

機能 PR を作成する際は、変更内容に応じて次の基準でテストを追加する。

- `domain`・`application` に新しい業務ロジックを追加した場合: 対応する Unit Test を
  追加する。
- `designsystem`・`apps/app` に新しい Widget や画面を追加した場合: 表示内容と
  ユーザー操作を検証する Widget Test を追加する。見た目の回帰を防ぎたい共通 Widget は
  Golden Test の追加も検討する（基盤導入後）。
- 主要ユーザーフローに影響する変更を行った場合: Patrol シナリオの追加・更新を
  検討する（基盤導入後）。
- 不具合を修正した場合: その不具合を再現するテストを追加する。
- どのレイヤーにも当てはまらない変更（設定ファイルのみの変更など）は、
  無理にテストを追加せず、レビューで代替の確認方法を示す。
