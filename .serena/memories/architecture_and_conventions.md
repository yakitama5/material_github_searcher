# アーキテクチャとコーディング規約

## オニオンアーキテクチャ（依存方向）
内側のレイヤーから外側のレイヤーをimportしてはならない。

```
app --> designsystem --> application --> domain --> foundation
app --> application
app --> dependency_override --> infrastructure --> domain
```

- `domain`/`foundation` はコア（同心円最内側）。外側のどのパッケージからも直接依存してよい。
- コア以外の依存はこの図に描かれたものだけに限定する。`designsystem`は`infrastructure`/`dependency_override`/`app`を直接参照しない。
- `tools/check_package_dependencies.dart`（`dart run tools/check_package_dependencies.dart`）で依存方向を機械的に検査。CI（`check_pr.yaml`の`check_package_dependencies`ジョブ）でも実行。

## 依存性逆転と結線
- リポジトリのインターフェースは`domain`に置き、実装は`packages/infrastructure/*`に置く。`application`は`domain`の抽象のみに依存。
- 結線は独立した`dependency_override`パッケージが担当。`apps/app`はcomposition root（`main.dart`の`createApp`）でoverrideを適用。
- 通常起動: `createProductionOverrides()`。Widget Test/Patrol: `createMockOverrides()`または対象Providerのみのoverride。
- 画面固有のViewModelは追加せず、Application Providerをアプリ状態のSingle Source of Truthとする。公開Providerは`packages/application/lib/application.dart`からexport。

## 命名規則
- パッケージ名に`packages_`接頭辞は付けない。責務を表すsnake_case（`foundation`, `domain`, `application`, `designsystem`, `dependency_override`）。
- `packages/infrastructure/<adapter>`は`infrastructure_<adapter>`と命名（例: `infrastructure_mock`, `infrastructure_github`）。

## デザイン方針（`docs/design.md`）
- MD3準拠（`useMaterial3`は既定true、`ColorScheme.fromSeed`を使用）。
- レスポンシブはデバイス種別でなく幅で判断。画面全体は`MediaQuery.sizeOf`、Widget内部は`LayoutBuilder`。`OrientationBuilder`は使わない。
- Window size class: compact(0-599dp) / medium(600-839dp) / expanded(840dp以上)。値は`packages/designsystem/lib/src/layout/breakpoints.dart`の`Breakpoints`/`WindowSizeClass`で一元管理。
- 画面回転を抑制する設定は追加しない。
- Skeletonは`packages/designsystem`の`SkeletonScope`/`SkeletonBox`/`SkeletonText`/`SkeletonCircle`を使い、外部Skeletonパッケージは導入しない。

## その他の方針
- Melosは不使用（Pub Workspaceのみ）。複数パッケージ横断テストが必要になるまで導入しない。
- 依存バージョンは`any`やキャレット範囲でなく個別固定バージョンで明記。SDKバージョンは`mise.toml`が唯一の正。
- plans/配下はプロダクトコードのコメントから参照しない（理由は直接コメントに記載する）。
