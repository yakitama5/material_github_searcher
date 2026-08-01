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

`packages/application`の状態管理ライブラリにはRiverpodを採用し、Providerはgeneratorを
使わず手書きする。Application層はFlutter SDKへ依存せず`package:riverpod`を利用し、
Flutter Widget側だけが`package:flutter_riverpod`を利用する。画面固有のViewModelは
追加せず、Application Providerをアプリ状態のSingle Source of Truthとして扱う。
使い分けは次のとおり。

- `application`単体のUnit Testでは`ProviderContainer`を生成し、検証したいProvider
  だけをoverrideしてFakeに差し替える。テスト終了時はContainerを必ず破棄する。
- Widget Testでは本番と同じ`createApp`を使い、テスト固有の差し替えが必要な場合だけ
  `createApp`の`overrides`へ対象Providerのoverrideを渡す。
- アプリ全体を起動する E2E Test（Patrol）では、Provider 単位で個別に override せず、
  `dependency_override` が公開する Mock 向け override 一式をそのまま適用し、
  実装コードを変更せずに Fake へ切り替える。

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
Widget Test など高速かつ決定的なテストのみを対象にする。Golden Test は
OS 間の描画差により決定的に比較できないため CI 対象外とし、ローカルでの
実行のみに限定する（詳細は後述の「Golden Test 基盤」を参照）。Patrol による
E2E Test も Required Status Check に含めず、ローカルで実行する。この境界は
`check_pr.yaml` 冒頭のコメント（`BuildとPatrolは実行時間・安定性の観点から対象外とする。`）
で既に運用上の決定として明文化されており、本ドキュメントはこれを踏襲する。

現状の`test`ジョブは`test/tools`、`packages/application`、`packages/designsystem`、
`apps/app`のテストを実行する。`packages/domain`等に`test/`を追加した時点で、それらも
CI対象に含める必要がある。パッケージ横断でテストを一括実行する仕組み（Melos等）は、
`docs/ARCHITECTURE.md` が定義するとおり複数パッケージのテストが実際に必要になった
段階で再検討する。現時点ではパッケージごとに `dart test` / `flutter test` を
直接実行する。

## Golden Test と Patrol の位置付け

- **Golden Test**: `packages/designsystem` の共通 Widget の見た目の回帰を検出する。
  ロジックではなく描画結果の変化を検知する目的に限定し、頻繁に変化するレイアウトや
  `apps/app` の画面全体には適用しない。
- **Patrol**: 実機・エミュレータ上で複数画面をまたぐ主要ユーザーフロー
  （例: 検索してリポジトリ詳細を開く）を検証する E2E Test。外部サービスへの
  依存は `dependency_override` で決定的な Fake に差し替えたうえで実行する。

### Patrol E2E Test 基盤（`apps/app`）

Patrol Testは`apps/app/patrol_test/`へ配置し、ローカルのAndroid実機または
iOS Simulatorで実行する。iOS物理端末は対象外とする。環境構築と端末接続の詳細は
`docs/development.md`を参照する。

```sh
# リポジトリルートで実行する
mise run test:e2e <Android device ID または iOS Simulator ID>
```

共通タスクはDev Flavorと`apps/app/flavor/dev.json`を必ず使用する。iOSではDev Schemeと
DevのBundle IDを使い、SwiftPMを維持した`RunnerUITests` targetから起動する。端末localeによる
結果差を防ぐため、`patrol_test/support/pump_test_app.dart`で`AppLocale.ja`へ固定して
から、本番と共通の`createApp`をpumpする。テスト側から`main()`、`runApp()`、
`WidgetsFlutterBinding.ensureInitialized()`は呼ばない。

Patrolは主要ユーザーフローを検証するE2E Testとして扱い、起動だけの確認は追加しない。
現在の`apps/app/patrol_test/main_user_flows_test.dart`は、次の3シナリオを独立した
`patrolTest`として持つ。

- 起動時の日本語案内と初期Lottieを確認し、検索を実行する。結果一覧のSkeletonから
  Repository名・owner icon・言語を確認し、OpenContainerでDetailへ遷移する。
  Detail APIが未完了でもSummary（Star・Watcher・Fork・Issue）を即時表示し、Watcher
  だけSkeletonになること、API完了後に`subscribers_count`が表示されることを確認する。
- 30件の1ページ目から無限scrollで2ページ目を取得し、Pull to Refreshの「更新中」表示と
  再取得結果を確認する。その後、別queryで0件検索を行い、Empty Lottieと空状態文言を確認する。
- 再検索後に検索履歴の候補を選択し、Settingsへ遷移する。License一覧を開いてアプリ名を
  確認し、戻る操作でSettingsへ復帰する。

各シナリオは`createMockOverrideSet()`から新しいMockとメモリ上のFake Preferencesを
生成し、同じ`createApp` Composition RootへProvider overrideとして渡す。検索・Detailの
応答はFixtureと`Completer`で成功・0件・pagination・遅延を決定的に設定するため、実GitHub
APIや`SharedPreferences`へ接続しない。Patrolテストから`infrastructure_mock`を直接参照せず、
`dependency_override/testing.dart`が公開するテスト用型を利用する。

画面の状態遷移はKey・Semantics・Widget type・Provider応答の完了状態で待ち、固定sleepや
アプリ全体の`pumpAndSettle`には依存しない。初期案内・Skeleton・Empty・Refresh indicatorは
自律アニメーションを持つため、アニメーションの静止ではなく必要な状態の出現を待つ。
テストは通常の`createApp`を使い、Device Preview用entrypointやPreview専用Composition Rootは
使わない。対象は検索・Detail・履歴・Settings・Licenseの主要フローに限定し、Widget Testは
単一画面の状態・操作、Golden Testは共通Widgetの描画回帰を担当する。

### Golden Test 基盤（`packages/designsystem`）

Golden Test ライブラリは [alchemist](https://pub.dev/packages/alchemist) を使う。

**Golden Test は CI では実行せず、コミット前にローカルで実行して見た目の変化に
気づくための開発者向けチェックと位置付ける。** 導入時に検証した結果、
alchemist の CI Golden（`Ahem` フォント固定でプラットフォーム間の描画差を吸収する
仕組み）を使っても、円形アイコンなどアンチエイリアシングを伴う描画は macOS
ローカルと Linux 上の GitHub Actions runner で微小に異なり、`diffThreshold: 0`
では決定的に比較できないことが分かった。Docker 等で CI と同一の描画環境を
再現する運用コストは、現状の規模（個人開発、PR 作成者がそのままレビューも行う）
に見合わないと判断し、CI での強制は行わない方針とした。この判断により
「CI 環境で決定的に比較できる」という当初の想定は満たさない。将来チーム開発になる、
または Golden 化するコンポーネントが増えて重要度が上がった場合は、
CI runner を `macos-latest` にする等の再導入を検討する。

- 共通設定は `packages/designsystem/test/flutter_test_config.dart` に置く。
  CI Golden（`goldens/ci/`、Ahemフォント固定で文字が読めないブロック表示になる）は
  `CiGoldensConfig(enabled: false)` で無効化し、実フォント・実アイコンで描画され
  人が読める **プラットフォーム Golden（`goldens/<platform>/`）のみ**を比較対象にする。
- 画面サイズは各シナリオ（`GoldenTestScenario`）を `SizedBox` で固定して包む。
  locale はシナリオを包む `MaterialApp` に `locale:` を明示指定して固定する。
  `MaterialApp` は既定では `supportedLocales` が `en_US` のみのため、`locale:` の
  指定だけでは実際のロケール解決に反映されない。`ja` を実際に反映させたい場合は
  `flutter_localizations`（`dev_dependencies` に `sdk: flutter` で追加）の
  `GlobalMaterialLocalizations.delegates` と、対象言語を含む `supportedLocales`
  も合わせて指定する。
- Golden Test には alchemist の `goldenTest` がデフォルトで `golden` タグを
  付与するが、意図を明示するためテストファイル先頭にも
  `@Tags(['golden'])` を明記する。CI（`check_pr.yaml`）はこのタグを使って
  `flutter test --exclude-tags=golden` を実行し、Golden Test を除外する。
- Golden 画像（`test/**/goldens/`）は Git 管理する。差分確認用の一時出力
  （`test/**/failures/`）のみ `.gitignore` で除外する。
  **コミットする Golden 画像は生成した環境（現状は開発者の macOS）に固有**であり、
  他 OS 上で生成し直すと差分が出る可能性がある点に留意する。

```sh
cd packages/designsystem

# 通常のWidget Test・Unit Testのみ実行(Golden Testを除外。CIもこのコマンドを使う)
flutter test --exclude-tags=golden

# Golden Testのみ実行(コミット前にローカルで必ず実行する)
flutter test --tags=golden

# Golden画像を更新(見た目の変更を意図的に行った場合)
flutter test --tags=golden --update-goldens
```

Golden Test を持つ Widget を変更した場合は、コミット前に必ず
`flutter test --tags=golden` をローカルで実行し、意図しない見た目の変化が
無いことを確認する。見た目の変更を意図的に行った場合は、変更が意図したもので
あることを PR の説明に明記したうえで `--update-goldens` を実行し、
生成された Golden 画像を目視で確認してからコミットする。CI では実行されないため、
レビュアーは PR 説明にローカルでの Golden Test 実行結果（または確認済みの旨）が
記載されているかを確認する。

## テスト追加基準（今後の機能 PR 向け）

機能 PR を作成する際は、変更内容に応じて次の基準でテストを追加する。

- `domain`・`application` に新しい業務ロジックを追加した場合: 対応する Unit Test を
  追加する。
- `designsystem`・`apps/app` に新しい Widget や画面を追加した場合: 表示内容と
  ユーザー操作を検証する Widget Test を追加する。見た目の回帰を防ぎたい共通 Widget は
  Golden Test の追加も検討する。Golden Test は CI では実行されないため、
  追加・更新した場合は必ずコミット前にローカルで
  `flutter test --tags=golden` を実行して確認する。
- `apps/app` に翻訳リソース（`slang`）を追加・変更した場合: 対応するロケール
  （日本語・英語）ごとに表示文字列を検証する Widget Test を追加する。
  `LocaleSettings.setLocale` でロケールを明示的に指定し、端末ロケールに依存せず
  決定的に検証する。
- 主要ユーザーフローに影響する変更を行った場合: Patrol シナリオの追加・更新を
  検討する。外部サービスを利用する場合は、必ずFakeへ差し替える。
- 不具合を修正した場合: その不具合を再現するテストを追加する。
- どのレイヤーにも当てはまらない変更（設定ファイルのみの変更など）は、
  無理にテストを追加せず、レビューで代替の確認方法を示す。
