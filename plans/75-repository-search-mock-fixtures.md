# Issue #75 Repository検索用MockとFixtureを追加する

Issue: <https://github.com/yakitama5/material_github_searcher/issues/75>

## 目的

`#73`（コミット`f0ddff2`）で追加済みのRepository検索Domain契約
（`RepositorySearchRepository`）を満たす決定的なMockと、JSON非依存の
Domain fixtureを`infrastructure_mock`へ追加する。Widget Test・Provider
Test・PatrolがそれぞれFake Repositoryを重複定義せず、同じシナリオ
（成功・空・失敗・遅延・cancel・pagination）を再利用できるようにする。

## スコープ境界

- `packages/dependency_override`は変更しない。`createMockOverrides()`への
  結線は、Providerが存在する後続Issueに委ねる。
- HTTP JSON mapping、Application Provider、Widget、Golden、Detail用Mockは
  対象外（Issue本文の「対象外」節のとおり）。
- `docs/technical-decisions.md`は編集しない。

## 方針

### 公開契約の設計

`MockRepositorySearchRepository`は`(query, page)`をキーに応答を設定できる
Mapを持ち、`RepositorySearchQuery`・`RepositorySearchPage`ともDomainが
`==`/`hashCode`を実装済みのため、Recordキー`(RepositorySearchQuery, int)`を
そのまま`Map`キーに使える。

応答は成功・失敗を表すsealed class`MockRepositorySearchResponse`で表現し、
任意で「完了ゲート」用の`Completer<void>`を持たせることで、Completer分の
`complete()`が呼ばれるまで`search()`が完了しない遅延シナリオを表現する。
`search()`はこのゲートの`Future`と`cancellationToken.whenCancelled`を
`Future.any`で競わせ、キャンセルが先に完了すれば
`RequestCancelledException`を投げる。

呼出履歴は`RepositorySearchCall`（query/page/perPage）のListとして記録する。
記録は`throwIfCancelled()`より前に行い、「既にキャンセル済みで呼び出した
場合」も含めて呼出自体は必ず1件記録される仕様にする。

### パッケージ構成

```text
packages/infrastructure/mock/
├── pubspec.yaml                                       # test dev_dependency追加、domain依存のみ
├── lib/
│   ├── infrastructure_mock.dart                        # barrel export
│   └── src/
│       ├── repository/
│       │   ├── mock_repository_search_repository.dart
│       │   ├── mock_repository_search_response.dart
│       │   └── repository_search_call.dart
│       └── fixture/
│           ├── repository_summary_fixtures.dart
│           └── repository_search_page_fixtures.dart
└── test/
    ├── repository/mock_repository_search_repository_test.dart
    └── fixture/
        ├── repository_summary_fixtures_test.dart
        └── repository_search_page_fixtures_test.dart
```

### Fixture設計

`RepositorySummaryFixtures`（個別Repository）:

- `typical`: 代表的な複数件（identityは全て一意）。
- `nullLanguage`: `language == null`。
- `longFullName`: 非常に長い`fullName`（owner・name双方を長くする）。
- `brokenOwnerAvatar`: owner iconの読み込み失敗確認用。`*.invalid`
  TLD（RFC 2606で名前解決不能と予約された非実在ドメイン）を使い、実I/Oなしで
  決定的に失敗させる。

`RepositorySearchPageFixtures`（ページ単位）:

- `empty`: `totalCount == 0`、`items`空、`hasMore == false`。
- `firstPage`/`secondPageWithOverlap`: page1とpage2で1件だけidentityが
  重なるページの組。`RepositorySearchPage`のコンストラクタは
  `hasMore == (nextPage != null)`を強制するため、`firstPage`は
  `hasMore: true, nextPage: 2`、`secondPageWithOverlap`は
  `hasMore: false, nextPage: null`で構成する。

`typical`・`nullLanguage`・`longFullName`・`brokenOwnerAvatar`と
`firstPage`/`secondPageWithOverlap`内の非重複要素は、identityが互いに
一意であることをテストで検証する。重複はpage1/page2間の1件のみに限定し、
テストで「意図した重複」であることを明示する。

## テスト方針

- query/pageごとに異なるresponseを設定して`search()`が正しい応答を返す。
- 未設定の`(query, page)`を呼んだ場合の挙動（`StateError`）。
- 失敗注入（`RepositorySearchException`）でエラーを再現できる。
- 遅延応答：`Completer`を明示的に`complete()`するまで`search()`が完了しない。
- cancel：ゲート待機中のcancel、および呼び出し時点で既にキャンセル済みの
  ケースの双方で`RequestCancelledException`を投げつつ、呼出履歴には記録
  されることを確認する。
- 呼出履歴・呼出回数（`calls`/`callCount`）の検証。
- fixtureのidentity一意性（重複を除く）と、意図した重複の検証。

## CI

- `.github/workflows/check_pr.yaml`の`test`ジョブへ
  `infrastructure_mock`のテストステップを追加する。
- `tools/src/package_dependency_checker.dart`の許可グラフには
  `infrastructure_mock -> domain, foundation`が既に定義済みのため変更不要。
