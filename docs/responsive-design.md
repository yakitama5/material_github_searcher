# レスポンシブ対応方針

<!-- cspell:words designsystem sizeOf screenOrientation extralarge -->

本ドキュメントは、様々な画面幅に対応するためのレイアウト切り替えの判断基準と、
共通ブレークポイントの定義をまとめる。画面実装（検索画面・詳細画面等）の前に読み、
レイアウト分岐の実装方針を判断する材料とする。

## 判断基準の方針: デバイス種別ではなく利用可能幅で判断

選択はデバイスの種類（スマートフォン/タブレット等）ではなく、デバイスの利用可能な
ウィンドウサイズに基づく（[Flutter: Adaptive design – General
approach](https://docs.flutter.dev/ui/adaptive-responsive/general)）。本プロジェクトでも
`isMobile`/`isTablet`のようなデバイス種別による分岐は行わず、常に幅（dp）で判断する。

### MediaQuery.sizeOf と LayoutBuilder の使い分け

- **画面全体のレイアウト切り替え**（例: ナビゲーションを`BottomNavigationBar`と
  `NavigationRail`で切り替える等）には`MediaQuery.sizeOf(context)`を使う。アプリ
  ウィンドウ全体の論理ピクセル幅を返し、`MediaQuery.of(context).size`と異なり
  必要なプロパティのみ購読するため、無関係な変更での再ビルドが少ない。
- **特定Widget内部でのローカルな折り返し判断**（親から与えられた制約幅に応じて
  Column数を変える等、画面幅とは限らない相対的なサイズが必要な場合）には
  `LayoutBuilder`を使う。`Size`ではなく`BoxConstraints`（最小・最大の有効な幅・
  高さ範囲）を返し、ウィジェットツリー内の位置に応じた制約を反映する。
- `OrientationBuilder`や`MediaQuery.orientation`はレイアウト分岐に使わない。
  [Flutter公式ガイド](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)が
  明示的に非推奨としている。本プロジェクトは後述のとおりPortraitに固定しているため
  orientation分岐自体がそもそも不要になるが、方針として明文化しておく。

## 画面回転はPortraitに固定する

画面回転は抑制せずサポートする案も検討したが、最終的にPortrait（縦向き）へ固定する
方針とした（Landscapeはサポートしない）。

- iOS: `apps/app/ios/Runner/Info.plist`の`UISupportedInterfaceOrientations`・
  `UISupportedInterfaceOrientations~ipad`を`UIInterfaceOrientationPortrait`のみに
  限定している。あわせて`UIRequiresFullScreen`を`true`にしている。iPadOSは
  Slide Over/Split View等のマルチタスキングが有効な状態だと
  `UISupportedInterfaceOrientations~ipad`の制限を無視して回転を許可するため、
  `UIRequiresFullScreen`が無いとiPadで固定が効かない
  （引き換えにiPadでのマルチタスキング表示はできなくなる）。
- Android: `apps/app/android/app/src/main/AndroidManifest.xml`の`<activity>`に
  `android:screenOrientation="portrait"`を設定している。
- 今後の画面PRでこれらの設定を緩め、回転を許可する変更は行わない。

Portrait固定後も、iPadなど画面幅の広い端末をPortraitで利用した場合は後述の
`expanded`クラスの幅になり得るため、幅ベースのブレークポイント自体は引き続き
必要になる。

## ブレークポイント定義

Material Design 3 の
[Window size classes](https://m3.material.io/foundations/layout/breakpoints/overview)
のうち、本プロジェクトはモバイルアプリ（スマートフォン・タブレット）を対象とし、
デスクトップ/外部ディスプレイ相当の`large`/`extraLarge`までは対象としないため、
**compact/medium/expandedの3段階**に絞って採用する。

| Window size class | 幅の範囲 (dp) | 代表機種の例（portrait幅） |
| --- | --- | --- |
| compact | 0–599 | iPhone 17 Pro（402pt） |
| medium | 600–839 | iPad mini（744pt） |
| expanded | 840以上 | iPad Pro 12.9インチ（1024pt） |

`large`/`extraLarge`は将来デスクトップ・外部ディスプレイ対応が要件化した時点で
追加を検討する（`expanded`の上限を設けず「840以上」としているのはこのため）。

これらの値は`packages/designsystem`の`WindowSizeClass` enumと`Breakpoints`定数
（`packages/designsystem/lib/src/layout/breakpoints.dart`）として一箇所で管理し、
`package:designsystem/designsystem.dart`からexportしている。

```dart
final windowSizeClass = WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
```

## 大画面（expandedクラス）時の最大コンテンツ幅の方針

Flutterの[large-screensガイド](https://docs.flutter.dev/ui/adaptive-responsive/large-screens)は
「テキストやボックスがウィンドウ全幅を占めるべきではない」とし、具体的な数値は
Material 3側の推奨値を参照するよう案内しているが、Material 3自体は
list-detail・feed・supporting-paneなどレイアウトパターンごとに異なる最大幅を
示しており、単一の数値は明記していない。

本プロジェクトでは`expanded`クラスの下限値と同じ840dp
（`Breakpoints.maxContentWidth`）を最大コンテンツ幅とする。iPad Pro 12.9インチ
（1024pt）上では中央に840pt幅のカラムが表示され、左右に約92ptずつの余白ができる。
compact/mediumクラス（0–839dp）は幅が常に840dp未満のため、この制限自体が効かず
画面幅をそのまま使う。実装は`ConstrainedBox`等で`maxWidth:
Breakpoints.maxContentWidth`を指定し中央寄せする形を想定する。

## Widget Testの共通方針（代表画面幅）

`designsystem`・`apps/app`のWidget Testで、画面幅に応じた表示を検証する際は
次の方針に従う（詳細は`docs/testing.md`を参照）。

- `tester.view.physicalSize`と`tester.view.devicePixelRatio`を設定し、各Window
  size classの代表幅でテストする（`addTearDown(tester.view.reset)`で後続テストへの
  影響を防ぐ）。
- 代表幅は、各Window size classにつき1つ、現行の主流機種の論理幅を採用する。
  - compact: 402（iPhone 17 Pro）
  - medium: 744（iPad mini）
  - expanded: 1024（iPad Pro 12.9インチ）
- 全てのWidget Testに全代表幅を要求するのではなく、幅によって表示・レイアウトが
  変わるWidget/画面に限定して追加する。

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

## 対象外

- 検索画面・詳細画面の具体的なレスポンシブ実装
- `responsive_framework`の導入
- DevicePreviewの導入
- 共通Widget（`ResponsiveContentWidth`のようなラッパー等）の実装
- Widget Test用の共通テストヘルパー（ユーティリティ関数等）の実装
- デスクトップ・外部ディスプレイ向けの`large`/`extraLarge`クラスの追加
