# テスト戦略

<!-- cspell:words designsystem -->

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
| `packages/dependency_override` | － | 実装の結線のみを担うため個別のテストは設けず、`apps/app` の Widget Test・E2E Test で間接的に検証する |
| `packages/foundation` | Unit Test | ロジックを持つユーティリティを追加した場合のみ、対象箇所に Unit Test を追加する |
| `apps/app` | Widget Test | 画面の表示、ユーザー操作（tap 等）、ルーティング |
| 主要ユーザーフロー | E2E Test（Patrol） | 複数画面をまたぐ実利用シナリオ |

`packages/application` は状態管理ライブラリとして Riverpod を想定している
（本ドキュメント執筆時点では `pubspec.yaml` に未追加で、正式な採用は未確定）。想定する
使い分けは次のとおり。

- `application` 単体の Unit Test では、検証したい Provider だけを
  `ProviderContainer`/`ProviderScope` の override 機能で Fake に差し替える。
- アプリ全体を起動する E2E Test（Patrol）では、Provider 単位で個別に override せず、
  `dependency_override` が公開する Mock 向け override 一式をそのまま適用し、
  実装コードを変更せずに Fake へ切り替える。

具体的な実装パターン（Provider の書き方など）は、Riverpod の採用が確定した後に
本ドキュメントへ追記する。

## 配置と命名規約

- テストは対象コードと同じパッケージの `test/` 配下に置き、対象コードのパスと
  対称になるディレクトリ構成にする（例: `lib/src/config/app_build_config.dart` に対して
  `test/config/app_build_config_test.dart`）。
- テストファイル名は対象ファイル名に `_test.dart` を付けた名前にする。
- `tools/` 配下のスクリプトに対するテストは、対象パッケージを持たないため
  リポジトリ直下の `test/tools/` に置く（既存の `sync_sdk_versions_test.dart` などを
  踏襲する）。

## 画面幅に応じたWidget Test

`designsystem`・`apps/app`で、幅によって表示・レイアウトが変わるWidget/画面の
Widget Testを書く場合は、`tester.view.physicalSize`と`tester.view.devicePixelRatio`
を設定し、代表的な画面幅で検証する（`addTearDown(tester.view.reset)`で後続テストへ
の影響を防ぐ）。判断基準・ブレークポイントの定義自体は `docs/design.md`
を参照する。

代表幅は、Window size class（compact/medium/expanded）につき1つ、現行の主流機種の
論理幅を採用する。

- compact: 402（iPhone 17 Pro）
- medium: 744（iPad mini）
- expanded: 1024（iPad Pro 12.9インチ）

`tester.view.physicalSize`は幅・高さのペアが必要になる。高さも検証に絡む場合は、
各機種のportrait時の論理高さ（874 / 1133 / 1366）を目安にする。幅のみで判定する
テストでは高さは固定値（例: 900）でよい。

全てのWidget Testに全代表幅を要求するのではなく、幅によって表示・レイアウトが
変わるWidget/画面に限定して追加する（前述の「変更した振る舞いをテストする」方針に
従う）。

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
`check_pr.yaml` 冒頭のコメント（`BuildとPatrolは実行時間・安定性の観点から対象外とする。`）
で既に運用上の決定として明文化されており、本ドキュメントはこれを踏襲する。

現状の `test` ジョブは `test/tools` と `apps/app` の `flutter test` のみを実行して
おり、`packages/domain` 等に `test/` を追加した時点で、それらも CI 対象に含める
必要がある。パッケージ横断でテストを一括実行する仕組み（Melos 等）は、
`docs/ARCHITECTURE.md` が定義するとおり複数パッケージのテストが実際に必要になった
段階で再検討する。現時点ではパッケージごとに `dart test` / `flutter test` を
直接実行する。

## Golden Test と Patrol の位置付け

- **Golden Test**: `packages/designsystem` の共通 Widget の見た目の回帰を検出する。
  ロジックではなく描画結果の変化を検知する目的に限定し、頻繁に変化するレイアウトや
  `apps/app` の画面全体には適用しない。
- **Patrol**: 実機・エミュレータ上で複数画面をまたぐ主要ユーザーフロー
  （例: 検索してリポジトリ詳細を開く）を検証する E2E Test。外部サービスへの
  依存は `dependency_override` で決定的な Fake に差し替えたうえで実行する想定とする。
- Patrol は本ドキュメント執筆時点では基盤（セットアップ）を導入していない。
  基盤導入は別 Issue で行い、導入後に実行コマンドを本ドキュメントへ追記する。

### Golden Test 基盤（`packages/designsystem`）

Golden Test ライブラリは [alchemist](https://pub.dev/packages/alchemist) を使う。

- 共通設定は `packages/designsystem/test/flutter_test_config.dart` に置く。
  `--dart-define=CI=true` の有無でプラットフォーム Golden（`goldens/<platform>/`、
  実際のフォントで描画される人が読める画像）の生成有無を切り替える。
- alchemist は CI Golden（`goldens/ci/`）をデフォルトで常に生成・比較する。
  CI Golden はプラットフォーム間の描画差を避けるため **フォントを `Ahem` に固定し、
  文字列は色付きブロックとして描画する**（アイコンやアイコン背景色などフォント
  以外の描画は通常どおり比較対象になる）。CI（`check_pr.yaml`）では
  `flutter test --dart-define=CI=true` を実行し、この CI Golden のみで決定的に
  比較する。
- 画面サイズは各シナリオ（`GoldenTestScenario`）を `SizedBox` で固定して包む。
  locale はシナリオを包む `MaterialApp` に `locale:` を明示指定して固定する。
  `MaterialApp` は既定では `supportedLocales` が `en_US` のみのため、`locale:` の
  指定だけでは実際のロケール解決に反映されない。`ja` を実際に反映させたい場合は
  `flutter_localizations`（`dev_dependencies` に `sdk: flutter` で追加）の
  `GlobalMaterialLocalizations.delegates` と、対象言語を含む `supportedLocales`
  も合わせて指定する。
- Golden Test には alchemist の `goldenTest` がデフォルトで `golden` タグを
  付与するが、意図を明示するためテストファイル先頭にも
  `@Tags(['golden'])` を明記する。
- Golden 画像は `test/**/goldens/ci/` 配下のみ Git 管理する。プラットフォーム
  Golden（`test/**/goldens/<platform>/`）と差分画像（`test/**/failures/`）は
  環境依存のため各パッケージの `.gitignore` で除外する。
- プラットフォーム Golden は Git 管理しないため、`clone` 直後や `.gitignore` 対象を
  削除した直後にローカルで `--dart-define=CI=true` なしの `flutter test` を実行すると、
  比較対象のプラットフォーム Golden 画像が存在せず失敗する。その場合は一度
  `flutter test --update-goldens` を実行してプラットフォーム Golden を生成する
  （CI Golden 側は `test/**/goldens/ci/` に既にコミットされているため上書きされる
  差分がないか確認したうえでコミットする）。

```sh
cd packages/designsystem

# 通常のWidget Test・Unit Testのみ実行(Golden Testを除外)
flutter test --exclude-tags=golden

# Golden Testのみ実行
flutter test --tags=golden

# Golden画像を更新(見た目の変更を意図的に行った場合)
flutter test --tags=golden --update-goldens

# 全テストをCIと同条件(決定的な比較)で実行
flutter test --dart-define=CI=true
```

Golden 画像を更新する際は、変更が意図したものであることを PR の説明に明記した
うえで `--update-goldens` を実行し、生成された差分画像を目視で確認してから
コミットする。

## テスト追加基準（今後の機能 PR 向け）

機能 PR を作成する際は、変更内容に応じて次の基準でテストを追加する。

- `domain`・`application` に新しい業務ロジックを追加した場合: 対応する Unit Test を
  追加する。
- `designsystem`・`apps/app` に新しい Widget や画面を追加した場合: 表示内容と
  ユーザー操作を検証する Widget Test を追加する。見た目の回帰を防ぎたい共通 Widget は
  Golden Test の追加も検討する（基盤導入後）。
- `apps/app` に翻訳リソース（`slang`）を追加・変更した場合: 対応するロケール
  （日本語・英語）ごとに表示文字列を検証する Widget Test を追加する。
  `LocaleSettings.setLocale` でロケールを明示的に指定し、端末ロケールに依存せず
  決定的に検証する。
- 主要ユーザーフローに影響する変更を行った場合: Patrol シナリオの追加・更新を
  検討する（基盤導入後）。
- 不具合を修正した場合: その不具合を再現するテストを追加する。
- どのレイヤーにも当てはまらない変更（設定ファイルのみの変更など）は、
  無理にテストを追加せず、レビューで代替の確認方法を示す。
