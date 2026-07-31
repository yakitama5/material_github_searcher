# Issue #85 Repository Detail Providerにdisposeキャンセルと成功時5分キャッシュを追加する

Issue: <https://github.com/yakitama5/material_github_searcher/issues/85>

## 目的

`RepositoryDetailRepository`（`#84`で追加済み）を`RepositoryIdentity`単位で
呼び出す手書きRiverpod Providerを追加する。通信中に最後のlistenerが外れれば
`CancellationController`でcancelし、成功結果だけ最後のlistenerが外れてから
5分間`ref.cacheFor`（`#71`で追加済み）でcacheする。

## 前提・依存

`#68`・`#71`・`#75`・`#84`は全てmerge済み。既存基盤（すべて変更不要、参照のみ）:

- `ref.cacheFor(Duration)` / `ref.createCancellationController()`
  （`packages/application/lib/src/core/extension/ref_extension.dart`）
- `RepositoryDetailRepository`・`RepositoryDetailSupplement`
  （`packages/domain/lib/src/repository/detail/`）
- `GitHubRepositoryDetailRepository`（`packages/infrastructure/github`）・
  `MockRepositoryDetailRepository`（`packages/infrastructure/mock`）
- `createProductionOverrides()`・`createMockOverrides()`
  （`packages/dependency_override/lib/src/override_sets.dart`）

## 方針

### Application（`packages/application`）

```text
lib/src/repository/detail/
├── repository_detail_repository_provider.dart  # 注入Provider
└── repository_detail_provider.dart             # FutureProvider.autoDispose.family + cache定数
```

`repository_search_repository_provider.dart`と同型で注入Providerを追加する。

```dart
final repositoryDetailRepositoryProvider = Provider<RepositoryDetailRepository>(
  (ref) => throw UnimplementedError(
    'repositoryDetailRepositoryProvider must be overridden. '
    'Apply createProductionOverrides() or createMockOverrides().',
  ),
);
```

Providerとcache duration定数を追加する。

```dart
const repositoryDetailCacheDuration = Duration(minutes: 5);

final repositoryDetailProvider = FutureProvider.autoDispose.family<
  RepositoryDetailSupplement,
  RepositoryIdentity
>((ref, identity) async {
  final repository = ref.watch(repositoryDetailRepositoryProvider);
  final controller = ref.createCancellationController();
  final result = await repository.fetch(
    identity,
    cancellationToken: controller.token,
  );
  // 成功後にのみ呼ぶ。開始時に呼ぶとkeepAliveが常時有効になり、cancel時に
  // 呼ぶとerror/cancel後もcacheされてしまう（ref_extension.dartのdoc契約）。
  ref.cacheFor(repositoryDetailCacheDuration);
  return result;
});
```

- `RequestCancelledException`はcatchしない。cancelを起こすのは
  `createCancellationController`が`onDispose`へ接続する`controller.cancel()`
  のみであり、cancelが発生する時点でProvider要素は既にdispose中のため、
  生きているlistenerが結果（reject）を観測することはない。検索Controllerの
  `_generation`/`_isStale`によるstale防御は、`FutureProvider.family`が
  identityごとに1要素・1Futureを管理し、dispose済み要素の結果を公開しない
  ため不要（過剰な多重防御を避ける）。
- `retry: (_, _) => null`を明示する。Riverpodの`FutureProvider`は既定で
  error時に`ProviderContainer.defaultRetry`による指数バックオフの自動retry
  （`Error`のサブクラス以外の例外が対象、最大10回）を行う。本Issueの契約
  「Retryは`ref.invalidate`に固定する」と衝突し、`RepositoryDetailException`
  （`Error`ではない）に対してレート制限のあるGitHub APIへ意図せず自動再試行
  してしまうため、明示的に無効化する（実装中に発覚。動作確認は下記テストの
  「error時はAsyncErrorへ遷移する」が無効化前は自動retryにより
  `TimeoutException`でタイムアウトすることで検証済み）。
- `application.dart`へ両ファイルのexportを追加する。

### dependency_override（`packages/dependency_override`）

`createProductionOverrides()`・`createMockOverrides()`双方へ追加する。

```dart
// createProductionOverrides()
repositoryDetailRepositoryProvider.overrideWith((ref) {
  final dio = createGitHubDio();
  ref.onDispose(dio.close);
  return GitHubRepositoryDetailRepository(dio: dio);
}),

// createMockOverrides()
repositoryDetailRepositoryProvider.overrideWith(
  (ref) => MockRepositoryDetailRepository(),
),
```

Searchと同じくProviderが初めて参照された時点で`Dio`を遅延生成し、dispose時に
`close`する。

## テスト（`packages/application/test/repository/detail/`）

`ref_extension_test.dart`と同じ`fake_async` + `ProviderContainer`パターンで、
`MockRepositoryDetailRepository`をoverrideして検証する。

- 成功時: `AsyncData`へ遷移し、`cacheFor`相当のkeepAliveが成立する
  （listenerを外しても即disposeされない）。
- 成功後5分未満での再購読: Repository呼出し回数が増えない（cache hit）。
- 成功後5分経過: 再購読でRepositoryが再度呼ばれる。
- error: `AsyncError`へ遷移し、cacheされない（listenerを外すと即dispose）。
- 通信中に最後のlistenerが外れる: `MockRepositoryDetailRepository`の`gate`で
  待機させ、`whenCancelled`が完了する（cancelされる）ことを検証する。
- 同一identityの同時複数listener: Repository呼出しが1回だけ。
- 異なるidentity: 別々のstate・cacheになる（一方のcacheが他方に影響しない）。
- `ref.invalidate(repositoryDetailProvider(identity))`によるretry: 再取得され
  Repository呼出し回数が増える。
- 成功直後・最後のlistener消失と同時にcacheForを呼ぶ境界: `fake_async`で
  `sub.close()`と成功完了のタイミングを重ねても`keepAlive`が正しく機能し、
  disposeされたProvider要素への操作でエラーにならないことを確認する。

`sub.close()`・`container.invalidate()`後のdispose・再計算判定は、Riverpodの
内部scheduler（`Timer(Duration.zero)`）経由で実行される。`fake_async`の
`flushMicrotasks()`はTimerを実行しないため検知できず、`elapse(Duration.zero)`
（またはそれ以上のelapse）でタイマーを消化する必要がある（実装中に発覚）。

## `ref.cacheFor`（`#71`）の追加修正（本Issueで発覚）

`fetch`成功と最後のlistener消失がほぼ同時に起きる場合、`ref.cacheFor`
（`packages/application/lib/src/core/extension/ref_extension.dart`）の
`onCancel`登録が「listenerが0になった」イベントを取りこぼし、cache期間が
過ぎても`keepAlive`が解除されず無期限に保持され続けるバグをコードレビューで
検出した（`fake_async`で実際に再現：`cacheDuration + 1秒`経過後も
Repositoryが再呼出しされないことを確認）。

原因はRiverpod本体の`Ref.isPaused`のdocコメントに明記された既知の制約
「buildが非同期処理をawait中に全listenerが外れた場合、`onCancel`はbuildの
途中で既に発火済みのため、その後`onCancel`を登録しても再度は呼ばれない」。
`#85`の`repositoryDetailProvider`が、`cacheFor`を非同期ギャップ（await）の
**後**で呼ぶ初めての利用者であり、`#71`はこの経路を検証していなかった。

修正は個別Providerではなく`cacheFor`本体（`#71`が追加した共通拡張）に行う。
`cacheFor`呼び出し時点で`ref.isPaused`が`true`（＝既にlistenerが0）なら、
`onCancel`の発火を待たず直接timerを開始する。将来の非同期ギャップを持つ他の
`FutureProvider`が同じ`cacheFor`を使う際にも同様に机上の空論で終わらせず
安全にする。回帰確認として、`ref_extension_test.dart`（`#71`のテスト）へ
直接の regression testを追加し、既存の同期的な`cacheFor`テスト3件が全て
通ることも確認する。

## 実装手順

1. `packages/application`: 注入Provider追加→`repositoryDetailProvider`追加→
   `application.dart`のexport更新。
2. `packages/application/test`: 上記テストケースを追加。
3. `packages/dependency_override`: production/mock双方のoverride追加。
   個別テストは設けない（`docs/testing.md`の方針どおり、`apps/app`側で間接
   検証）。
4. 全体検証（下記）を実行する。

## テスト観点（全体検証）

- `cd packages/application && mise exec -- flutter test`が通る。
- `mise exec -- dart run tools/check_package_dependencies.dart`が通る
  （`dependency_override`の依存追加はGitHub/Mock双方とも既存許可依存の範囲内）。
- `mise exec -- dart format --output=none --set-exit-if-changed apps packages
  test tools`、`mise exec -- dart analyze --fatal-infos`、
  `mise exec -- dart tools/sync_sdk_versions.dart --check`が通る。

## 対象外

- Detail API mapping（`#84`で対応済み）。
- Detail Page、Skeleton、OpenContainer。
- Deep Link。
- 永続cache。
- `docs/technical-decisions.md`の編集。
