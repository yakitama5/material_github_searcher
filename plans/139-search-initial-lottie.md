# Issue #139 未検索初期状態の専用Lottie案内

## 目的

`RepositorySearchStatus.initial`を検索結果0件の表示から意味の異なる専用案内へ置き換える。
検索結果0件の`RepositorySearchEmpty`と`woman_empty_box.json`は既存の意味・表示を維持する。

## 方針

- `RepositorySearchLottieMessage`を検索feature内の共通Widgetとして追加する。
  - Lottieの読み込み、`AnimationController`、Reduce Motion、`ExcludeSemantics`、共通レイアウトを担当する。
  - アセット読み込みに失敗しても、タイトルと補足文を共通Widgetの外側で表示する。
- `RepositorySearchInitial`と`RepositorySearchEmpty`は薄いラッパーとし、アセット・翻訳キー・Reduce Motion時の静止位置だけを決める。
- `SliverFillRemaining(hasScrollBody: false)`のintrinsic size制約を維持するため、共通Widgetは`Center`、`Padding`、`Column(mainAxisSize: MainAxisSize.min)`で構成し、`LayoutBuilder`や`Expanded`を使わない。
- `RepositorySearchMessageView`は初回エラーとRetry表示の責務に限定する。
- initial専用翻訳キーを日本語・英語へ追加し、slang生成コードを更新する。
- `search_initialize.json`をFlutter assetへ登録し、出典・作者・ライセンスをREADMEへ記録する。
- Screen Testは無限再生の影響を受けないようReduce Motionを有効にしてpumpし、通常再生・静止位置・asset失敗・Semanticsは共通Widget Testで検証する。

## 状態契約

| 状態 | 表示 |
| --- | --- |
| `initial` | `RepositorySearchInitial`、初期案内Lottie、initial用文言 |
| `loading` | 既存Skeleton |
| `success`かつ0件 | 既存`RepositorySearchEmpty`、`woman_empty_box.json` |
| `success`かつ1件以上 | 既存Repository一覧 |
| `error` | 既存Error・Retry表示 |

Controllerの状態モデル、初期表示時のAPI未呼出、検索開始後にinitialへ戻さない契約は変更しない。

## 検証項目

- initial表示、API未呼出、日英翻訳、assetの差異
- `initial → loading → data/empty/error`でinitialが残らないこと
- Reduce Motion時の静止、通常時の再生、MediaQuery変更への追従
- Lottie読み込み失敗時の文言表示、LottieのSemantics除外
- 狭幅・大きなText Scale・intrinsic layoutでのoverflowなし
- 既存Emptyの文言・asset・Pull to Refreshを維持すること
