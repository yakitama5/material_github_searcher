# Issue #46 レスポンシブ対応方針と画面回転時のレイアウト基準を定義

## 目的

様々な画面幅に対応するため、レイアウト切り替えの判断基準と共通ブレークポイントを
定義する。現時点で検索画面・詳細画面は未実装（`apps/app`はカウンターのサンプル
画面のみ）のため、本Issueでは方針の文書化とdesignsystemへの定数・分類ロジックの
実装に留め、個別画面のレスポンシブ実装は対象外とする。

**方針転換の経緯:** Issue起票時点では画面回転（Portrait/Landscape）を両方サポート
する前提だったが、検討の結果、画面回転はPortraitに固定する方針へ変更した。これに
伴い、GitHub Issue #46の概要・完了条件も更新済み。

## 参照した一次情報

- <https://docs.flutter.dev/ui/adaptive-responsive/general>
- <https://docs.flutter.dev/ui/adaptive-responsive/best-practices>
- <https://docs.flutter.dev/ui/adaptive-responsive/large-screens>
- <https://m3.material.io/foundations/layout/breakpoints/overview>（Window size
  classesの幅の閾値）
- 代表機種の論理解像度（幅・pt）: iPhone 17 Pro 402pt、iPad mini（第7世代）portrait
  744pt、iPad Pro 11インチ portrait 834pt、iPad Pro 12.9インチ portrait 1024pt
  （Apple公開仕様・各種ビューポート一覧サイトで確認）

## 判断基準の方針: デバイス種別ではなく利用可能幅で判断

Flutter公式ガイド（General approach）は「選択はデバイスの種類ではなく、デバイスの
利用可能なウィンドウサイズに基づくべき」と明記している。本プロジェクトでも
`isMobile`/`isTablet`のようなデバイス種別による分岐は行わず、常に幅（dp）で判断する
方針を明文化する。

### MediaQuery.sizeOf と LayoutBuilder の使い分け

公式ガイドの使い分けをそのまま採用する。

- **画面全体のレイアウト切り替え**（例: ナビゲーションを`BottomNavigationBar`と
  `NavigationRail`で切り替える等）には`MediaQuery.sizeOf(context)`を使う。アプリ
  ウィンドウ全体の論理ピクセル幅を返し、`MediaQuery.of(context).size`と異なり
  必要なプロパティのみ購読するため、無関係な変更での再ビルドが少ない。
- **特定Widget内部でのローカルな折り返し判断**（親から与えられた制約幅に応じて
  Column数を変える等、画面幅とは限らない相対的なサイズが必要な場合）には
  `LayoutBuilder`を使う。`Size`ではなく`BoxConstraints`（最小・最大の有効な幅・
  高さ範囲）を返し、ウィジェットツリー内の位置に応じた制約を反映する。
- `OrientationBuilder`や`MediaQuery.orientation`はレイアウト分岐に使わない。公式
  ガイドが明示的に非推奨としている。本プロジェクトはPortrait固定のためorientation
  分岐自体がそもそも不要になるが、方針として明文化しておく。

## 画面回転をPortraitに固定する

対応方針を検討した結果、画面回転はPortraitへ固定する（Landscapeはサポートしない）。

- iOS: `apps/app/ios/Runner/Info.plist`の`UISupportedInterfaceOrientations`および
  `UISupportedInterfaceOrientations~ipad`から`UIInterfaceOrientationLandscapeLeft`・
  `UIInterfaceOrientationLandscapeRight`・`UIInterfaceOrientationPortraitUpsideDown`
  を削除し、`UIInterfaceOrientationPortrait`のみを残す。あわせて
  `UIRequiresFullScreen`を`true`にする。iPadOSはSlide Over/Split View等の
  マルチタスキングが有効な状態だと`UISupportedInterfaceOrientations~ipad`の制限を
  無視して回転を許可するため、`UIRequiresFullScreen`が無いとiPadで固定が効かない
  （引き換えにiPadでのマルチタスキング表示はできなくなる）。iPad Pro 11インチ
  シミュレータで実機検証し、Simulatorの回転操作後もPortraitのまま変化しないことを
  確認済み。
- Android: `apps/app/android/app/src/main/AndroidManifest.xml`の`<activity>`に
  `android:screenOrientation="portrait"`を追加する。
- 上記2点をもって「画面回転を抑制する設定」とし、GitHub Issue #46の完了条件
  （更新後）を満たす。

Portrait固定後も、iPadなど画面幅の広い端末をPortraitで利用した場合はexpanded
クラスの幅になり得るため、幅ベースのブレークポイント自体は引き続き必要になる
（後述）。

## ブレークポイント定義

Material Design 3 の Window size classes のうち、本プロジェクトはモバイルアプリ
（スマートフォン・タブレット）を対象としデスクトップ/外部ディスプレイ相当の
large・extraLargeまでは対象としないため、**compact/medium/expandedの3段階**に
絞って採用する。

| Window size class | 幅の範囲 (dp) | 代表機種の例（portrait幅） |
| --- | --- | --- |
| compact | 0–599 | iPhone 17 Pro（402pt） |
| medium | 600–839 | iPad mini（744pt） |
| expanded | 840以上 | iPad Pro 12.9インチ（1024pt） |

`large`/`extraLarge`は将来デスクトップ・外部ディスプレイ対応が要件化した時点で
追加を検討する（`expanded`の上限を設けず「840以上」としているのはこのため）。

`packages/designsystem/lib/src/layout/breakpoints.dart`に定数と分類ロジックを
定義し、`designsystem.dart`からexportする。Flutter依存のみで`domain`等の下位
レイヤーに依存しない値のため、`docs/ARCHITECTURE.md`の責務表にある`designsystem`の
「テーマ、共通Widget、画面に依存しないUI表現」に合致する。

```dart
/// Material Design 3 の Window size classes に基づく幅の分類。
///
/// 参考: https://m3.material.io/foundations/layout/breakpoints/overview
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// 利用可能な幅(dp)から対応する [WindowSizeClass] を求める。
  factory WindowSizeClass.fromWidth(double width) {
    if (width >= Breakpoints.expanded) return WindowSizeClass.expanded;
    if (width >= Breakpoints.medium) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }
}

/// Window size class の下限値(dp)。
abstract final class Breakpoints {
  static const double compact = 0;
  static const double medium = 600;
  static const double expanded = 840;
}
```

`WindowSizeClass.fromWidth`にUnit Testを追加する（後述）。

## 大画面（expandedクラス）時の最大コンテンツ幅の方針

Flutter公式ガイド（best practices / large-screens）は「テキストやボックスが
ウィンドウ全幅を占めるべきではない」とし、具体的な数値はMaterial 3側の推奨値を
参照するよう案内しているが、Material 3自体はlist-detail・feed・supporting-pane
などレイアウトパターンごとに異なる最大幅を示しており、単一の数値は明記していない。

`expanded`クラスの下限値である840dpを最大コンテンツ幅とする。iPad Pro 12.9インチ
（1024pt）上では中央に840pt幅のカラムが表示され、左右に約92ptずつの余白ができる。
compact/mediumクラス（0–839dp）は幅が常に840dp未満のため、この制限自体が効かず
画面幅をそのまま使う。超過分は`ConstrainedBox`等で`maxWidth`を指定し中央寄せする
形で実装する。

```dart
abstract final class Breakpoints {
  static const double compact = 0;
  static const double medium = 600;
  static const double expanded = 840;

  /// expandedクラスでコンテンツが無制限に広がらないようにする際の最大幅。
  /// expandedの下限値と同じにしているため、compact/mediumクラス
  /// （width < expanded）では常に制限が効かない。
  static const double maxContentWidth = expanded;
}
```

## Widget Testの共通方針（代表画面幅）

`docs/testing.md`に、`designsystem`・`apps/app`のWidget Testで画面幅に応じた表示を
検証する際の共通方針を追記する。

- `tester.view.physicalSize`と`tester.view.devicePixelRatio`を設定し、
  各Window size classの代表幅でテストする（`addTearDown(tester.view.reset)`で
  後続テストへの影響を防ぐ）。
- 代表幅は、各Window size classにつき1つ、現行の主流機種の論理幅を採用する。
  - compact: 402（iPhone 17 Pro）
  - medium: 744（iPad mini）
  - expanded: 1024（iPad Pro 12.9インチ）
- 高さは各機種のportrait時の論理高さ（874 / 1133 / 1366）を目安とするが、
  横幅のみで判定するテストでは固定値（例: 900）でよい。
- 全てのWidget Testに全代表幅を要求するのではなく、「幅によって表示・レイアウトが
  変わるWidget/画面」に限定して追加する（`docs/testing.md`の「変更した振る舞いを
  テストする」方針に従う）。

## responsive_framework を採用しない理由

- 本プロジェクトはデバイス種別ではなく`MediaQuery.sizeOf`/`LayoutBuilder`による
  幅ベースの判断のみで、Flutter標準APIの範囲内で要件を満たせる。
- `responsive_framework`はアプリ全体をスケーリングする`ResponsiveWrapper`を
  提供するが、これはウィジェットツリーの上位に強い制約を持ち込み、
  `docs/ARCHITECTURE.md`の依存関係（`app`→`designsystem`）に対して
  スケーリングの責務をどちらが持つかという新たな設計判断を追加で必要とする。
  現時点でその複雑さに見合う要件（例: Web版で細かなスケーリング調整が必須）が
  ない。
- 再評価条件: 複数画面でMaterial 3の標準ブレークポイントだけでは表現しきれない
  細かなスケーリング調整（フォントサイズの連続的な拡縮等）が複数箇所で必要に
  なった時点で再評価する。

## ドキュメントの配置

新規に`docs/responsive-design.md`を作成し、上記方針をまとめる。

- `docs/testing.md`のWidget Test方針から参照リンクを追加する。
- `docs/ARCHITECTURE.md`の`designsystem`責務説明から参照リンクを追加する。
- `AGENTS.md`（`.claude`/`.codex`から参照される実体）の「## 定義」に
  `レスポンシブ対応方針: docs/responsive-design.md`のエントリを追加する。

`docs/technical-decisions.md`は運用上エージェントに編集させないドキュメント
（ファイル冒頭に明記されている）ため、`responsive_framework`不採用理由もここには
書かず、新規`docs/responsive-design.md`内に記載する。

## テスト

- `WindowSizeClass.fromWidth`に対するUnit Testを
  `packages/designsystem/test/layout/breakpoints_test.dart`へ追加する
  （境界値: 599/600、839/840を含む）。
- Portrait固定設定そのもの（`Info.plist`/`AndroidManifest.xml`）はネイティブ設定の
  ため、Widget Test/Unit Testの対象にはならない。目視確認で担保する（後述）。

## CIへの反映

`packages/designsystem`にUnit Testを追加するため、本Issueで
`.github/workflows/check_pr.yaml`の`test`ジョブへ`packages/designsystem`向けの
`flutter test`ステップを追加する。あわせて`.github/scripts/detect_ci_changes.sh`の
既存の`test`判定条件（`*.dart`等で発火）はパッケージを問わず既にカバーしているため、
判定ロジック自体の変更は不要と見込む（実装時に既存のtest対象ケース
`.github/scripts/test_detect_ci_changes.sh`で回帰がないことを確認する）。

## 検証

- `mise exec -- dart format` で追加・変更したファイルを整形する。
- `mise exec -- flutter analyze`（`packages/designsystem`）で静的解析を実行する。
- `mise exec -- flutter test`（`packages/designsystem`）でUnit Testを実行する。
- `npx markdownlint-cli2` / `npx cspell` でドキュメント追加分を検証する。
- iOS シミュレータ・Androidエミュレータ双方で、端末を回転させてもレイアウトが
  Portraitのまま変化しないことを目視確認する。iOS
  はiPhone 17 Pro・iPad Pro 11インチ（M5）シミュレータで確認済み。Android は
  ローカル環境にエミュレータ（AVD）が未構成のため未検証。`android:screenOrientation
  ="portrait"`はAndroid標準の属性で挙動が確立しているが、実機/エミュレータでの
  最終確認はレビュー時またはローカルにAVDがある環境で行う。

## 対象外

- 検索画面・詳細画面の具体的なレスポンシブ実装
- `responsive_framework`の導入
- DevicePreviewの導入
- 共通Widget（`ResponsiveContentWidth`のようなラッパー等）の実装。方針と定数の
  定義に留める。
- Widget Test用の共通テストヘルパー（ユーティリティ関数等）の実装。方針の文書化に
  留める。
- デスクトップ・外部ディスプレイ向けの`large`/`extraLarge`クラスの追加。

## 追記: ドキュメント構成の見直し

Draft PR作成後、Android実機（Pixel 8a）での動作確認と合わせてレビューがあり、
`docs/responsive-design.md`をレスポンシブ専用ドキュメントとして厚く書くのではなく、
MD3準拠や今後実装する画面のデザイン方針全般を記載する`docs/design.md`へ統合し、
レスポンシブに関する記述は「想定デバイスと表示切り替え方法」程度に大幅に簡潔化する
方針へ変更した。本plan・`docs/testing.md`に残す詳細な設計根拠（一次情報の引用、
検討した代替案等）は経緯の記録として維持し、実装が読む生きたドキュメント
（`docs/design.md`）側は簡潔さを優先する。

## 追記: Android大画面端末でのPortrait固定の限界（CodeRabbit指摘対応）

PR #61へのCodeRabbitレビューで、`android:screenOrientation="portrait"`だけでは
Android 16（`targetSdkVersion` 36、Flutter 3.44系のGradle Plugin既定値）以降、
smallestWidthが600dp以上の大画面端末（タブレット・展開時のフォルダブル等）で
システムがこの指定を無視するという指摘を受けた。[Android公式ドキュメント](https://developer.android.com/about/versions/16/behavior-changes-16)
で裏取りした結果、指摘は正確だった。

- 対応: `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`
  プロパティを`AndroidManifest.xml`の`<application>`へ追加し、現行の
  `targetSdkVersion` 36の間はPortrait固定を維持する。
- 制約: このプロパティによるopt-outはAndroid公式ドキュメントで
  「`targetSdkVersion` 37では廃止される」と明言されている。`docs/flutter-upgrade.md`
  に沿ってFlutterをアップグレードし`targetSdkVersion`が37以上になった時点で、
  大画面Android端末でのPortrait固定は（アプリ側の設定によらず）保証できなくなる。
  その時点で「画面回転をPortraitに固定する」という本Issueの前提自体を再評価する
  必要がある。`docs/design.md`にも同様の注記を追加した。

## 追記: 画面回転固定方針の撤回

上記のAndroid 16の挙動変更は、単なる技術的な回避策が必要という話にとどまらず、
「Googleが大画面端末での回転・リサイズ制限を意図的に撤廃する方向へ進んでいる」
という設計方針の裏付けだった。この方針とアプリ側で回転を固定し続けることは
反する（`targetSdkVersion` 37到達後は固定を維持する手段がそもそも無くなる）ため、
Portrait固定という方針自体を撤回し、Issue起票時の前提（画面回転を抑制しない）へ
戻すことにした。

- iOS（`Info.plist`）・Android（`AndroidManifest.xml`）の変更を全て元に戻した
  （`UIRequiresFullScreen`・`UISupportedInterfaceOrientations`の制限・
  `android:screenOrientation`・`PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`の
  いずれも削除。`git diff main`で差分が無いことを確認済み）。
- `docs/design.md`の「画面回転はPortraitに固定」節を「画面回転を抑制しない」節へ
  書き換えた。個々の画面が回転時にどうレイアウトを切り替えるかは、各画面の
  デザイン時に決定する対象外事項とした。
- 本Issue自体は当初から「画面回転を抑制しない」前提だったため、GitHub Issue #46の
  本文もこの前提に戻した（詳細な経緯はIssue本文の追記コメントを参照）。
- `packages/designsystem`のブレークポイント判断（`WindowSizeClass.fromWidth`、
  `MediaQuery.sizeOf`ベースの幅判定）はorientationに依存しない設計のため、
  この方針転換によるコード変更は発生しない。
- iOSシミュレータ（iPhone 17 Pro）・Android実機（Pixel 8a）の双方で撤回後の
  ビルドを実行し、回転操作（Simulatorの回転コマンド／`adb shell settings put
  system user_rotation`）でLandscape表示に切り替わることを確認した。
