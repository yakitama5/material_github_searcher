# Issue #50 Dev/Prod アプリの任意実行 Build Workflow

## 目的

Dev/Prod の Flavor 設定が Android と iOS の実ビルドで成立することを任意のタイミングで
検証し、生成物を GitHub Actions Artifact として取得できる Workflow を追加する。
ビルド時間が長い処理は PR の必須チェックや `main` push の自動処理へ含めない。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/50>

## 前提確認の結果

- `apps/app/flavor/dev.json` と `prod.json` が存在し、Android の Product Flavor と iOS の
  共有 Scheme（`dev` / `prod`）は導入済みである。
- `docs/development.md` に、Android Debug APK と署名不要の iOS Simulator Build を
  Dev/Prod の双方で実行するコマンドが記載済みである。
- Flutter/Dart は `mise.toml` で固定され、既存 CI は
  `.github/actions/setup-flutter/action.yaml` を共通利用している。新規 Workflow もこの
  Composite Action を利用し、別の SDK 解決経路を増やさない。
- Issue #49 の変更パス判定と Issue #51 の Required Status Check 集約は導入済みで、
  現在の必須チェックは `.github/workflows/check_pr.yaml` の `Status Check` だけである。
- GitHub API で `main` の Branch Protection を確認した結果、Required Status Check
  `Status Check`、PR 経由の変更、管理者へのルール適用、Force Push・削除の禁止が設定
  されている。
- 参照先 `yakitama5/nanto_nack` の `build_and_publish.yml` は、手動入力、プラットフォーム
  別 Job、Cider によるバージョン更新、Flutter セットアップ、成果物アップロードの構成を
  参考にできる。一方、コミット・タグの直接 push、Firebase/環境ファイルの Secrets 復元、
  Release 署名、Codemagic CLI Tools、App Store Connect / Google Play 配布は本 Issue の
  対象外である。
- 保護された `main` への直接 push が必要な処理は採用しない。新規 Workflow は
  Repository Contents の読み取りと Artifact の作成だけを行うため、`main` を選んだ
  手動ビルドも Branch Protection と衝突しない。

## 採用する構成

### 手動入力と起動条件

- `.github/workflows/build_app.yaml` を追加し、起動イベントは `workflow_dispatch` のみに
  する。`push` と `pull_request` は設定しない。
- `flavor` は必須の Choice Input とし、`dev` / `prod` から1つを選択する。
- `platform` は必須の Choice Input とし、`all` / `android` / `ios` から選択する。
- `bump_type` は必須の Choice Input とし、`none` / `patch` / `minor` / `major` / `build`
  から選択する。既定値は `none` とする。
- Workflow と各 Job の `permissions` は `contents: read` に限定する。
- `actions/checkout` と `actions/upload-artifact` は既存 CI と同様に、採用するリリースの
  immutable な Commit SHA へ固定する。参照 Workflow の可変な Major Version Tag は
  そのまま移植しない。
- Workflow 名と Job 名に `Status Check` を使わず、Branch Protection の Required
  Status Check と明確に分離する。
- 同一 ref・Flavor・Platform・Version Bump の再実行を `concurrency` でまとめ、進行中の
  古い実行をキャンセルする。

### Cider によるバージョン更新

- Cider は現在の安定版 `0.2.10` へ固定し、各 Build Job 内で
  `dart pub global activate cider 0.2.10` により導入する。
- Repository ルートの `pubspec.yaml` には `version` がないため、Cider の `bump` と
  `version` は必ず `working-directory: apps/app` で実行する。Global Executable の PATH
  に依存しないよう、呼び出しは `dart pub global run cider ...` に統一する。
- `bump_type=none` の場合は `apps/app/pubspec.yaml` を変更せず、現在の Version で
  Build する。
- `patch` / `minor` / `major` は Cider の対応 Part を `--bump-build` 付きで実行し、
  SemVer 部分と Build Number を同時に更新する。`build` は Build Number だけを更新する。
- Android と iOS の各 Job は同じ Checkout 元と Input から同じ Cider コマンドを実行する
  ため、Platform が `all` の場合も両成果物の Version を一致させる。
- 更新後に `cider version` を実行して Build Log へ出力し、Artifact 名にも Version を
  含める。
- `pubspec.yaml` の変更は Runner 上だけに存在し、その実行の成果物へ反映する。
  Git commit、tag、push、Repository Contents の更新は行わない。

### Android Build

- `ubuntu-latest` で、選択 Platform が `all` または `android` の場合だけ実行する。
- Job の `timeout-minutes` は 30 分とする。
- Checkout 後、既存の Setup Flutter Composite Action を使い、必要なら Cider で
  `apps/app/pubspec.yaml` の Version を更新してから、`apps/app` で`flutter pub get`を
  実行する。Buildは`--no-pub`を指定し、依存解決を繰り返さない。
- `apps/app` で選択 Flavor の Debug APK を次の形で生成する。
  `flutter build apk --flavor <flavor> --debug
  --dart-define-from-file=flavor/<flavor>.json`
- Debug APK は Android の Release 署名や Keystore Secrets を必要とせず、Flavor 設定の
  整合性検証と端末での確認に使える。本 Issue では AAB と Release Build は生成しない。
- Flavor を含む名前で APK を Artifact に保存し、保持期間を明示する。対象パスは
  `apps/app/build/app/outputs/flutter-apk/app-<flavor>-debug.apk` に限定し、アップロード前に
  `test -f` で存在を検査する。Artifact Action にも `if-no-files-found: error` を指定し、
  出力パスが変わった場合に成功扱いにしない。
- Build 後に Android SDK の APK 解析Toolで `versionName` と `versionCode` を読み出し、
  Cider が出力した SemVer と Build Number に一致することを検証する。不一致なら
  Artifact をアップロードせず Job を失敗させる。

### iOS Simulator Build

- `macos-latest` で、選択 Platform が `all` または `ios` の場合だけ実行する。
- Job の `timeout-minutes` は 45 分とする。
- Android と同じ Checkout、Setup Flutter、Cider、`apps/app` での`flutter pub get`の
  経路を使い、Buildは`--no-pub`を指定する。
- `apps/app` で選択 Flavor の署名不要 Debug Simulator Build を次の形で生成する。
  `flutter build ios --flavor <flavor> --debug --simulator
  --dart-define-from-file=flavor/<flavor>.json`
- 生成された `build/ios/iphonesimulator/Runner.app` は、実行権限とシンボリックリンクを
  保持するため macOS の `tar` で Flavor 名を含む `.tar.gz` に固めてから Artifact として
  保存する。`actions/upload-artifact` に `.app` ディレクトリを直接渡さない。証明書、
  Provisioning Profile、App Store Connect 認証情報は扱わない。
- Archive 前に `test -d apps/app/build/ios/iphonesimulator/Runner.app`、アップロード前に
  `test -f` で `.tar.gz` の存在を検査する。Artifact Action にも
  `if-no-files-found: error` を指定する。
- Archive 前に `.app/Info.plist` の `CFBundleShortVersionString` と `CFBundleVersion` を
  macOS 標準Toolで読み出し、Cider が出力した SemVer と Build Number に一致することを
  検証する。不一致なら Artifact を作成せず Job を失敗させる。

### `main` とデプロイの扱い

- `main` push による自動起動は追加しない。手動実行画面では必要な ref を選択でき、
  `main` も読み取り専用でビルドできる。
- Cider による Version 更新は Build Job の一時的な入力変換として採用するが、参照
  Workflow のバージョン更新 Commit・Tag・直接 push は移植しない。
- 署名、Secrets 復元、Codemagic CLI Tools のインストール、ストアへのアップロードは、
  実行Stepやコメントアウト済みコマンドとして Workflow に追加しない。
- YAML コメントでは、将来 CD として利用する場合に Debug / Simulator Build を Release
  Build へ置き換え、Secrets で署名情報・認証情報を供給したうえで、成果物生成後に
  内部テスト配布Stepを追加する拡張点を説明する。秘密情報の名前や実行可能な配布コマンドは
  記載しない。
- 将来の実運用では、署名情報と認証情報を GitHub Secrets 等で管理し、Codemagic CLI
  Tools などを用いて内部テスト配布する方針だけを文書化する。今回の Artifact は
  Flavor 検証用の Debug / Simulator 成果物であり、ストア提出物ではないことを明記する。

## ドキュメント

`docs/development.md` に GitHub Actions の Build Workflow 節を追加し、次を記載する。

- Actions 画面から Workflow、実行対象 ref、Flavor、Platform、Version Bump を選ぶ手順
- Workflow ファイルがデフォルトブランチへマージされた後に手動実行できること
- Version Bump は成果物にだけ反映され、Repository の `pubspec.yaml`、Commit、Tag は
  更新されないこと
- 実行結果の Artifacts から APK / iOS `.app` bundle を含む `.tar.gz` を取得する手順
- Debug APK と iOS Simulator Build の用途・制約
- PR 必須チェックと `main` push 自動実行の対象外であること
- 実運用時の署名情報・認証情報の Secrets 管理と、Codemagic CLI Tools 等による内部
  テスト配布を想定する方針
- 今回は署名、認証情報登録、ストア配布を実装しないこと

## 実装手順

1. `workflow_dispatch` の Flavor / Platform / Version Bump Input、最小権限、Concurrency、
   Android 30 分・iOS 45 分の Timeout を定義した `.github/workflows/build_app.yaml` を
   追加する。
2. 既存 Setup Flutter を利用する Android Debug APK Job と iOS Simulator Job を追加し、
   Platform Input による実行条件を設定する。各 Job で Cider `0.2.10` による同一の
   Version Bump を `apps/app` を作業ディレクトリとして適用し、Checkout と Artifact
   Action は Commit SHA へ固定する。
3. 各 Job で選択 Flavor と同名の JSON を渡してビルドする。Android は Flavor 別 APK、
   iOS は `.app` を権限保持用の `.tar.gz` に固めたファイルだけを Artifact として保存する。
   正確な出力パスを事前検査し、APK / Info.plist 内の Version が Cider の出力と一致する
   ことを確認する。Version 不一致または Artifact 不存在時はエラーにする。
4. Workflow 内へ、実行不能な署名・配布コマンドではなく、将来 CD 化する場合の署名・
   Secrets・内部テスト配布の拡張点を説明するコメントを追加する。
5. `docs/development.md` に手動実行、Version Bump の一時性、成果物取得、成果物の制約、
   将来のデプロイ方針を追記する。
6. YAML・式・Markdown の静的検査と Dev/Prod のローカルビルドを実行し、可能であれば
   ブランチ上の手動 Workflow で Android / iOS の実行と Artifact を確認する。

## 検証

- YAML Parser で `.github/workflows/build_app.yaml` を読み込めること
- `actionlint` が利用可能であれば新規 Workflow が成功すること
- `npx --yes cspell@10.0.1 --config cspell.jsonc --no-progress`
- `npx --yes markdownlint-cli2@0.23.2`
- `git diff --check`
- `cd apps/app && mise exec -- flutter build apk --flavor dev --debug
  --dart-define-from-file=flavor/dev.json`
- `cd apps/app && mise exec -- flutter build apk --flavor prod --debug
  --dart-define-from-file=flavor/prod.json`
- `cd apps/app && mise exec -- flutter build ios --flavor dev --debug --simulator
  --dart-define-from-file=flavor/dev.json`
- `cd apps/app && mise exec -- flutter build ios --flavor prod --debug --simulator
  --dart-define-from-file=flavor/prod.json`
- GitHub Actions の手動実行で `dev` / `prod` と `all` / `android` / `ios` を選べること
- `bump_type=none` で元の Version、`patch` / `minor` / `major` / `build` で Cider の規則に
  従った Version が Build Log と Artifact 名へ反映されること
- APK の `versionName` / `versionCode` と iOS Info.plist の
  `CFBundleShortVersionString` / `CFBundleVersion` が Cider の Version と一致すること
- Platform が `all` の場合、Android / iOS Artifact の Version が一致すること
- Workflow 終了後も Repository の `pubspec.yaml`、Commit、Tag が変更されないこと
- Android Job から選択 Flavor の APK、iOS Job から選択 Flavor の `.app` bundle を含む
  `.tar.gz` を Artifact として取得できること
- 想定する APK、`.app`、`.tar.gz` が存在しない場合に Job が失敗すること
- Checkout / Artifact Action が可変 Tag ではなく Commit SHA に固定されていること
- Required Status Check が引き続き `Status Check` のみで、新規 Build Job が追加されて
  いないことを GitHub の Branch Protection 設定で確認すること
- Workflow に push、署名、Secrets 復元、Codemagic CLI、ストア配布、コメントアウト済みの
  実行不能なデプロイ処理が含まれないこと
- 将来 CD 化する際の署名・Secrets・内部テスト配布の拡張点が、実行コードを伴わない
  コメントとドキュメントで説明されていること

## 完了条件との対応

- 手動実行時の Flavor 選択: `workflow_dispatch.inputs.flavor` で担保する。
- 任意の Version Bump: `workflow_dispatch.inputs.bump_type` と固定版 Cider で担保する。
- Android 成果物: 選択 Flavor の Debug APK Artifact で担保する。
- iOS Simulator Build: 選択 Flavor の署名不要 `.app` を権限保持した `.tar.gz` Artifact で
  担保する。
- Required Status Check 対象外: 手動起動専用、固有 Job 名、既存 Branch Protection の
  再確認で担保する。
- 実行手順とデプロイ方針: `docs/development.md` に記録する。
- 実行不能なデプロイ処理を残さない: 対象外処理のコマンドはコメントアウトせず省き、
  将来 CD 化するための設計意図だけを自然言語のコメントで残す。

## リスクと対策

- Flutter の出力パスが Flavor や SDK 更新で変わる可能性がある。
  - Artifact の対象を既知の Flavor 別ファイルへ限定し、ファイル不存在時は Job を
    失敗させて出力変更を検知する。
- macOS Runner は実行時間と利用コストが大きい。
  - 手動起動専用、Platform 選択、Concurrency、Job の Timeout で不要な消費を抑える。
- Debug APK を Prod Flavor で生成すると、ストア配布可能な Prod 成果物と誤解され得る。
  - Artifact 名とドキュメントで Debug / 検証用であることを明示する。
- iOS `.app` bundle は Simulator アーキテクチャ向けで、実機や App Store へ配布できない。
  - 成果物の用途と制約を実行手順へ明記する。
- `workflow_dispatch` は Workflow ファイルがデフォルトブランチに存在するときに利用できる。
  - マージ前の最終確認ではローカルビルドと静的検査を行い、マージ後に Actions 画面から
    実行して Artifact を確認する運用を記載する。
- Version Bump を Commit / Tag に残さないため、同じ ref と Input の再実行では同じ
  Version が生成される。
  - 今回は再現可能な検証成果物として扱う。将来 CD 化して永続的な Version を一意に
    発行する段階で、保護ブランチと整合する Version Commit / Tag 作成フローを別途設計する。
