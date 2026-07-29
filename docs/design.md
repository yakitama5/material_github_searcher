# デザイン方針

<!-- cspell:words designsystem sizeOf screenOrientation -->

本プロジェクトのUI/UXデザイン全般の方針をまとめる。Material Design 3（MD3）準拠を
基本とし、画面実装が進むにつれてテーマ・コンポーネント等の具体的な方針をここに
追記していく。

## Material Design 3準拠

FlutterのThemeDataは`useMaterial3`が既定で`true`（Flutter 3.16以降）のため、明示的な
設定は不要。`ColorScheme.fromSeed`等、MD3のカラーシステムに沿ったAPIを使う
（`apps/app/lib/main.dart`参照）。

## Skeleton

読み込み中の共通プレースホルダーは`packages/designsystem`の`SkeletonScope`と
`SkeletonBox`/`SkeletonText`/`SkeletonCircle`を使う。外部Skeleton packageは導入せず、
Flutter標準の`AnimationController`と`AnimatedBuilder`で実装する。

複数のプレースホルダーは同じ`SkeletonScope`で包む。Scope内部で1つだけTickerを所有し、
各プリミティブは同じanimationを購読するため、テキストの複数行などでControllerを増やさない。
Scopeの破棄時にはControllerも破棄する。`MediaQuery.disableAnimations`が有効な場合は
アニメーションを停止し、静的な表示へ切り替える。

色は`Theme.of(context).colorScheme`から導出する。通常色に
`surfaceContainerHighest`、ハイライトに`onSurfaceVariant`を8%のalphaで合成した色を使い、
その間を`easeInOut`で補間する。1200msの`repeat(reverse: true)`による穏やかな色pulseとし、
Light/DarkおよびDynamic Colorを含むColorSchemeの変更に追従する。Skeleton自体は意味を
持たない装飾なので、各プリミティブをSemantics treeから除外する。Repository固有の
Skeletonレイアウトはdesignsystemへ追加せず、各画面の責務とする。

Golden TestではScopeの1200ms周期に対して`tester.pump`へ固定のDurationを渡し、
アニメーション位相を決定的にする。repeat中のため`pumpAndSettle`は使わない。

## レスポンシブ対応

デバイス種別ではなく利用可能幅で判断する。画面全体のレイアウト切り替えには
`MediaQuery.sizeOf(context)`、Widget内部のローカルな折り返し判断には
`LayoutBuilder`を使う。`OrientationBuilder`/`MediaQuery.orientation`はレイアウト
分岐に使わない
（参考: [Flutter: Adaptive design](https://docs.flutter.dev/ui/adaptive-responsive/general)）。

### 想定デバイスとブレークポイント

Material Design 3の
[Window size classes](https://m3.material.io/foundations/layout/breakpoints/overview)
のうち、モバイルアプリとして必要な**compact/medium/expanded**の3段階を採用する。

| Window size class | 幅の範囲 (dp) | 代表機種の例（portrait幅） |
| --- | --- | --- |
| compact | 0–599 | iPhone 17 Pro（402pt） |
| medium | 600–839 | iPad mini（744pt） |
| expanded | 840以上 | iPad Pro 12.9インチ（1024pt） |

値は`packages/designsystem`の`Breakpoints`/`WindowSizeClass`
（`packages/designsystem/lib/src/layout/breakpoints.dart`）で一元管理する。

```dart
final windowSizeClass = WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
```

expandedクラスでは`Breakpoints.maxContentWidth`（840dp）を上限に`ConstrainedBox`等で
中央寄せし、コンテンツが無制限に広がらないようにする。

Widget Testで画面幅を検証する場合の代表幅・手順は`docs/testing.md`を参照。

### 画面回転を抑制しない

画面回転（Portrait/Landscape）を抑制する設定は追加しない。Android 16
（`targetSdkVersion` 36以降）では大画面端末（smallestWidth 600dp以上）で
`android:screenOrientation`がシステムに無視されるようになっており、Google自身が
大画面での回転・リサイズ制限を撤廃する方向へ進んでいる。この流れに逆行して
アプリ側で固定し続けるのではなく、回転にも幅ベースの判断（前述の
`MediaQuery.sizeOf`/`WindowSizeClass`）で追従する方針とする。

個々の画面が回転時にどうレイアウトを切り替えるかの具体的な設計は、各画面の
デザイン時に決定する（本ドキュメントの対象外）。

### responsive_frameworkは不採用

幅ベースの判断のみでFlutter標準APIの範囲内に収まるため導入しない。複数画面で
Material 3の標準ブレークポイントでは表現しきれない連続的なスケーリング調整が
必要になった時点で再評価する。

## 対象外

- 検索画面・詳細画面の具体的なレスポンシブ実装（画面回転時のレイアウトを含む）
- `responsive_framework`の導入（理由は前述）
- デスクトップ・外部ディスプレイ向けの`large`/`extraLarge`クラス
- macOS/Web/Windows/Linux向けの画面回転・レスポンシブ対応（iOS/Androidのみ対象）
