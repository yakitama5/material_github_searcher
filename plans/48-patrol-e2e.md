# Issue #48 Patrol E2E 基盤と起動 Smoke Test

## 目的

Android の Dev Flavor を実機で起動し、主要ユーザーフローを将来追加できる
Patrol E2E テスト基盤を整える。現時点では検索機能や外部サービス接続が未実装のため、
Dev 設定で実アプリのルート Widget が描画されることを確認する最小限の Smoke Test
までを対象とする。

## 前提確認の結果

- `docs/testing.md` のテスト戦略と Android の Dev/Prod Flavor は `main` に導入済み。
- Dev の Android Application ID は
  `com.example.material_github_searcher.dev`、表示名は
  `Dev - Material GitHub Searcher`。
- 現在の `domain`、`application`、`infrastructure_mock`、
  `dependency_override` には Repository、Provider、外部 I/O の実装がない。
  GitHub API 等へ接続するコードも存在しない。
- Riverpod の正式採用も未確定であるため、本 Issue のためだけに架空の Repository や
  DI ライブラリを追加しない。
- 今回は、本番とテストで共通利用できるアプリ生成経路へ設定を明示注入する。
  Repository 実装後は `dependency_override` が公開する Mock 向け override 一式を
  Patrol の共通起動処理へ渡す方針とし、実際の Fake 実装は機能実装時に追加する。
- E2E の最終確認は Android エミュレータではなく、接続済みの Android 実機で行う。
  調査時点の端末は Pixel 8a、Android 17（API 37）。端末 ID は環境固有のため
  設定ファイルやドキュメントへ固定しない。Issue 本文の「Android エミュレータ」から
  実機へ変更することはユーザー確認済みであり、この合意は本 Plan と最終報告に残す。
- Patrol の実行はローカル限定とし、GitHub Actions や Required Status Check へは
  追加しない。

## 採用する構成

### Patrol とテスト配置

- `apps/app` の `dev_dependencies` に `patrol: 4.8.0` をリポジトリ規約どおり
  固定バージョンで追加する。
- Patrol CLI は公式手順どおりグローバルツールとして `patrol_cli 4.6.1` を導入する。
  公式互換表では Patrol CLI 4.5.0 以降と Patrol 4.7.0 以降、Flutter 3.32.0 以降が
  対応するため、Flutter 3.44.8 を使う本リポジトリで成立する。
- セットアップ手順に `mise exec -- dart pub global activate patrol_cli 4.6.1`、
  pub global bin の
  `PATH` 設定、`ANDROID_HOME` 設定、`patrol doctor` を記載する。共通タスクでも
  CLI が 4.6.1 でなければ導入コマンドを示して fail-fast する。
- `apps/app/pubspec.yaml` の `patrol` セクションに Dev Flavor、Dev 表示名、最終的な
  Android Application ID を設定する。
- 公式既定の `apps/app/patrol_test/` を採用し、最初のテストを
  `app_smoke_test.dart` とする。
- 自動生成される `test_bundle.dart` と機密値を置き得る `.patrol.env` を
  `.gitignore` へ追加する。

### Android ネイティブ設定

Patrol 公式の Kotlin DSL 向け設定に従い、次を追加する。

- `apps/app/android/app/src/androidTest/java/com/example/material_github_searcher/MainActivityTest.java`
  - Patrol 4.x 公式例の `Parameterized` runner とし、`@Parameters` で
    `InstrumentationRegistry` から `PatrolJUnitRunner` を取得する。
  - `setUp(MainActivity.class)`、`waitForPatrolAppService()`、`listDartTests()` で
    Dart テストを列挙し、各 `@Test` から `runDartTest(dartTestName)` を実行する。
  - Java の package は既存 Activity の namespace と一致させる。Dev の
    Application ID suffix は package 宣言へ含めない。
- `apps/app/android/app/build.gradle.kts`
  - `PatrolJUnitRunner` を `testInstrumentationRunner` に指定する。
  - テスト間でアプリデータを消去する `clearPackageData` を有効化する。
  - AndroidX Test Orchestrator を使用する。
  - Patrol 4.x 公式手順と同じ AndroidX Test Orchestrator `1.5.1` を
    `androidTestUtil` へ追加する。

### アプリ起動と Fake 差し替え方針

- `apps/app/lib/main.dart` から、required な `AppBuildConfig` を受け取り
  `TranslationProvider` 以下のアプリを生成する `createApp` を抽出する。
  `AppBuildConfig.current` をデフォルト引数にせず、呼び出し元が必ず設定を渡す。
- 通常起動では従来どおり端末 locale を解決して `runApp` する。
- `apps/app/patrol_test/support/pump_test_app.dart` に Patrol 固有の共通起動 helper を
  置く。テストごとに `await LocaleSettings.setLocale(AppLocale.ja)` を完了させた後、
  Dev の dart-define から遅延初期化される `AppBuildConfig.current` を `createApp` へ
  明示的に渡し、共通のルート Widget を `pumpWidgetAndSettle` する。
- Patrol テストでは `main()`、`WidgetsFlutterBinding.ensureInitialized()`、`runApp()`、
  `LocaleSettings.useDeviceLocale()` を呼ばない。
- Smoke Test は Dev のアプリ名が画面に1件表示されることを検証する。これにより、
  アプリが描画されたことに加えて Dev Flavor と dart-define の取り違えも検出する。
- 現時点では外部 I/O が存在しないため、空の override や架空の Fake は追加しない。
  本番と Patrol が同じ `createApp` を利用し、Patrol 固有の pump を
  `pump_test_app.dart` に集約することを今回の Fake 注入基盤の成果物とする。
  外部サービスを利用する機能の実装時は、この helper を
  `dependency_override` の Mock override 一式を必須で受け取る形へ拡張する。

### 共通コマンドと文書

- `mise.toml` に `test:e2e` タスクを追加する。mise の `usage` で端末 ID を必須の
  positional argument として宣言し、リポジトリルートから
  `mise run test:e2e <Android device ID>` で実行できるようにする。
- タスクは working directory を `apps/app` とし、次を実施する。
  - `patrol --version` が `patrol_cli v4.6.1` であることを検査する。
  - `ANDROID_HOME` が設定されていることを検査する。
  - Patrol 内部がリポジトリ固定の Flutter を使うよう
    `PATROL_FLUTTER_COMMAND="mise exec -- flutter"` を設定する。
  - `patrol test --flavor dev --dart-define-from-file=flavor/dev.json
    --device <Android device ID>` を実行する。
- `docs/development.md` に次を記載する。
  - Patrol CLI の固定バージョン導入と `patrol doctor`
  - USB デバッグを有効にした Android 実機の接続、認証、`flutter devices` での確認
  - 共通コマンドと端末 ID の渡し方
  - 端末が見つからない、ADB 認証されない、CLI/package の互換性不一致、
    Gradle/Instrumentation build が失敗する場合のトラブルシュート
- `docs/testing.md` の Patrol 節を導入済みの状態へ更新し、ローカル実行方法と、
  検索機能完成後に現在の Smoke Test を「検索してリポジトリ詳細を開く」主要フローへ
  置き換える方針を明記する。

## 実装手順

1. Patrol 4.8.0 と Patrol CLI 4.6.1 の互換条件を再確認し、
   `apps/app/pubspec.yaml`、`pubspec.lock`、`.gitignore` を更新する。
2. Android の Instrumentation Test runner と Gradle 設定を追加する。
3. アプリ生成処理を抽出し、既存 Widget Test が同じ経路を利用するよう必要最小限に
   整理する。
4. `patrol_test/app_smoke_test.dart` を追加し、Dev 表示名を検証する。
5. `mise.toml` に版・環境・端末 ID を検証する共通 `test:e2e` タスクを追加する。
6. `docs/development.md` と `docs/testing.md` を更新する。
7. 静的検査・既存テスト・Dev build を実行する。
8. `patrol doctor` の Android 項目、`flutter devices`、USB デバッグ認証、実機の
   画面ロック解除を確認する。接続済み Android 実機を明示して
   `mise run test:e2e <Android device ID>` を実行し、Smoke Test の成功を確認する。
9. 差分全体をレビューし、Issue の完了条件と対象外を再確認して必要な修正を行う。

## 検証

- `mise exec -- flutter pub get`
- `mise exec -- dart format --output=none --set-exit-if-changed apps packages test tools`
- `mise exec -- dart analyze --fatal-infos`
- `mise exec -- dart test test/tools`
- `cd packages/designsystem && mise exec -- flutter test --exclude-tags=golden`
- `cd apps/app && mise exec -- flutter test`
- `mise exec -- dart run tools/check_package_dependencies.dart`
- `patrol --version`（`patrol_cli v4.6.1`）
- `PATROL_FLUTTER_COMMAND="mise exec -- flutter" patrol doctor`
- `mise exec -- flutter devices`
- `mise tasks validate`
- `mise run test:e2e --help`
- `cd apps/app && mise exec -- flutter build apk --flavor dev --debug
  --dart-define-from-file=flavor/dev.json`
- `npx --yes cspell@10.0.1 --config cspell.jsonc --no-progress`
- `npx --yes markdownlint-cli2@0.23.2`
- `mise run test:e2e <Android device ID>`
- `git diff` で `.github/workflows/` に変更がないことを確認する。

## 完了条件との対応

- Dev Flavor で Patrol をローカル実行できる
  - Patrol の Dev 設定と `mise run test:e2e` で担保する。
- Android で Smoke Test が成功する
  - ユーザー合意に基づき、Issue 本文のエミュレータ検証を接続済み Android 実機で
    代替し、Dev アプリ名の描画を検証する。
- テスト中に GitHub API 等の外部サービスへ接続しない
  - 現行コードに外部 I/O が存在しないことを確認し、架空の接続実装を追加しない。
    将来は `dependency_override` / `infrastructure_mock` による差し替えを必須とする。
- 共通コマンドで E2E を実行できる
  - リポジトリルートの `mise run test:e2e` を提供する。
- 後から Fake を注入する箇所が一意である
  - 本番と Patrol が required な設定を受ける同じ `createApp` を使用する。
  - Patrol 固有の起動処理を `patrol_test/support/pump_test_app.dart` に集約し、
    将来 Mock override 一式を受け取る箇所として文書化する。
- ローカル実行手順が記載されている
  - `docs/development.md` と `docs/testing.md` に環境、実行、問題解決手順を記載する。
- GitHub Actions に Patrol 実行が追加されていない
  - Workflow を変更せず、最終差分でも確認する。

## 対象外

- GitHub Actions、Required Status Check、PR Checker での Patrol 実行
- iOS、Android エミュレータ、Firebase Test Lab 等での E2E 実行
- 未実装の検索・詳細画面の E2E シナリオ
- Riverpod の採用、Repository 抽象、外部 API 実装、架空の Fake 実装
- 端末固有 ID の設定ファイルへの保存
- Patrol の動画記録やカバレッジ収集

## リスクと対策

- Patrol package と CLI の版ずれ
  - 固定バージョン、公式互換表、`patrol doctor`、実機テストで確認する。
- Flavor 設定と Patrol 設定の重複
  - Patrol には最終 Application ID が必要なため重複を許容し、値の由来と同期方法を
    文書化する。専用の設定生成ツールは本 Issue では追加しない。
- Android 17 / API 37 実機と現行ツール群の互換性
  - 接続確認、Dev APK build、Instrumentation 実行を段階的に行い、失敗時は
    ADB、Gradle、Patrol のどの層かを切り分ける。
- 実機の画面ロック、USB 認証、電池最適化等による不安定化
  - 実行前条件と代表的な復旧手順を `docs/development.md` に記載する。
- 将来、外部 API 実装後に Smoke Test が実通信を始める
  - 検索機能実装時に Smoke Test を主要検索フローへ置き換え、Mock override 一式を
    Patrol 起動 helper の必須入力に変更することをテスト方針へ明記する。

## 追記: 実装差分レビューによるDarwin生成物の整理

Patrol追加後にリポジトリルートで`flutter pub get`を実行したところ、iOS/macOS向けの
PodfileとPods xcconfig includeが自動生成された。実装差分レビューで、Patrol 4.8.0は
SwiftPM対応済みであり、既存のSwiftPM方針とAndroid限定の本IssueにCocoaPods経路は
不要との指摘を受け、これらの差分を除外した。

`apps/app`で改めて`flutter pub get`を実行し、PodfileとPods includeが再生成されず、
iOS/macOS双方のephemeralな`FlutterGeneratedPluginSwiftPackage/Package.swift`が
Patrol 4.8.0を解決することを確認した。macOSの`GeneratedPluginRegistrant.swift`は
Flutterが追跡対象として生成するプラグイン登録コードのため、Patrolの登録差分を保持する。
E2E Testの対応プラットフォームは引き続きAndroid実機のみとする。
