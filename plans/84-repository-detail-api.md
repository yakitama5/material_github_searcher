# Issue #84 Repository Detail APIと実Watcher数の取得を実装する

Issue: <https://github.com/yakitama5/material_github_searcher/issues/84>

## 目的

検索結果の`watchers_count`は実Watcher数ではないため使用せず、GitHub REST
`GET /repos/{owner}/{repo}`が返す`subscribers_count`を実Watcher数として取得
するDomain契約・`infrastructure_github`実装・`infrastructure_mock`実装を追加
する。`#73`の`RepositoryIdentity`・`RepositorySummary`は再定義せず再利用し、
`#74`の`infrastructure_github`（`dio`・`CancellationToken`接続・例外変換の型）
を踏襲して拡張する。

## Issue原文からの変更点

Issue本文の完了条件（behaviorテーブル）は`RateLimitException`・
`RepositoryNotFoundException`・`ApiException`・`DecodeException`という4種類の
個別例外型を挙げているが、次の理由により単一の`RepositoryDetailException`
（messageで理由を書き分ける）へ変更する。ユーザー確認済み。

1. `#74`の`RepositorySearchRepository`実装が既に同じ設計（単一の
   `RepositorySearchException`、message差分で403/429/404/その他/decodeを
   区別）を採用しており、`domain/error/app_exception.dart`のdocコメントも
   「要因ごとの分類が必要になった時点で…別サブタイプとして追加する」と
   明記した上で見送っている。
2. 後続`#86`（Detail画面）のWatcher行エラー表示は種別を問わず一律
   （Error+Retry）であり、呼び出し側に理由別分岐の実利用箇所がない。
3. Issue本文の完了条件リスト自体は「実HTTP処理をabortできる」
   「cancelをユーザー向けAPI errorへ変換しない」等の振る舞いレベルのみを
   求めており、型の個数（分類の粒度）は完了条件に含まれない。

`AbortableRequest`という文言もIssue原文にあるが、`#74`と同じく実装は`dio`の
`CancelToken`を`cancellationToken.whenCancelled.then((_) => cancelToken.cancel())`
で接続する方式を踏襲する（`http`パッケージ・`AbortableRequest`型は本リポジトリ
に存在せず、`#74`のplanで不採用と明記済み）。

`mapDioExceptionToAppException`（Search用）は変更しない。`#74`のplanが
「将来Detail API等の別adapterが増えた時点で共通化を再検討する」と明記して
いるが、既存の動作するSearch実装へ手を入れるリスクの方が、
Detail専用の小さな並行実装（`mapDioExceptionToDetailException`、
約40行）を1つ追加するコストより大きいと判断し、本Issueでは共通化しない。
共通化はSearch/Detail双方を触る後続の独立したリファクタリングIssueにて
再検討する。

## スコープ境界（重要）

- `packages/dependency_override`、Riverpod Provider、Detail Page、
  OpenContainer、Deep Linkは変更しない（Issue「対象外」に明記、後続の
  `#85`〜`#87`が担当）。
- `docs/technical-decisions.md`は編集しない。
- `RepositorySummary`の項目（name・image・language・Star・Fork・Issue）を
  `RepositoryDetailSupplement`へ複製しない。

## 方針

### Domain（`packages/domain`）

```text
lib/src/repository/detail/
├── repository_detail_supplement.dart   # RepositoryDetailSupplement
└── repository_detail_repository.dart   # RepositoryDetailRepository (abstract interface)
```

- `RepositoryDetailSupplement`: `identity`（`RepositoryIdentity`）・
  `subscribersCount`（`int`）のみを持つ`@immutable final class`。
  `RepositorySummary`と同じ形（`==`/`hashCode`実装）に揃える。
- `RepositoryDetailRepository`: `fetch(RepositoryIdentity identity, {required
  CancellationToken cancellationToken})`の単一メソッド抽象。
  `RepositorySearchRepository`と同じく`one_member_abstracts`をignoreし、
  公開契約どおりの単一メソッドである理由をコメントに残す。
- `app_exception.dart`へ`RepositoryDetailException`（`RepositorySearchException`
  と同じ形。`message`を任意で持つ）を追加する。
- `domain.dart`へ3つのexportを追加する。

### Infrastructure GitHub（`packages/infrastructure/github`）

```text
lib/src/
├── dto/
│   └── github_repository_detail_dto.dart      # subscribers_countのみ手書きdecode
├── error/
│   └── github_detail_exception_mapper.dart     # mapDioExceptionToDetailException()
└── repository/
    └── github_repository_detail_repository.dart # GitHubRepositoryDetailRepository
```

- DTO: `requireField<int>(json, 'subscribers_count')`のみを読む。
  `toDomain(RepositoryIdentity identity)`で`RepositoryDetailSupplement`へ変換
  する（`identity`はDTO側でdecodeせず呼び出し元が持つものをそのまま使う。
  レスポンスの`full_name`は読まない＝Summary項目の複製を避ける）。
- `GitHubRepositoryDetailRepository`: `Dio`をコンストラクタ注入。
  `GET /repos/${Uri.encodeComponent(identity.owner)}/${Uri.encodeComponent(identity.name)}`
  を呼ぶ。`cancellationToken.throwIfCancelled()`→`CancelToken()`生成→
  `whenCancelled.then((_) => cancelToken.cancel())`（`#74`と同一パターン）。
  例外処理は`on DioException`→`mapDioExceptionToDetailException`、
  `on FormatException`→`RepositoryDetailException`、その他→
  `UnknownException`（いずれも`Error.throwWithStackTrace`で再送出）。
- `mapDioExceptionToDetailException`: `mapDioExceptionToAppException`と同一
  構造（cancel/403+429 rate limit/404/その他statusCode/レスポンスなし）だが
  返す型が`RepositoryDetailException`である点だけが異なる。
- owner・nameのURIエンコードはdioの二重エンコードを疑い、
  `FakeHttpClientAdapter`の`capturedRequests`で実際に送信される
  `RequestOptions.path`／組み立て後のURIを検証するテストを書く
  （`.`・`-`等を含むowner/nameで確認）。

### Infrastructure Mock（`packages/infrastructure/mock`）

```text
lib/src/repository/
├── mock_repository_detail_repository.dart   # MockRepositoryDetailRepository
└── mock_repository_detail_response.dart     # sealed: Success/Failure
```

- `MockRepositorySearchRepository`と同じ形を踏襲する。キーは`RepositoryIdentity`
  単体（`search`と異なり`(query, page)`のタプルは不要）。
- 呼出履歴は`RepositorySearchCall`のような専用recordクラスを新設せず、
  `List<RepositoryIdentity>`をそのまま保持する（`fetch`の引数が`identity`
  1つだけのため、ラッパーを追加すると`RepositoryIdentity`の複製にしかなら
  ない）。
- `MockRepositoryDetailResponse`（sealed）: `MockRepositoryDetailSuccess`
  （`RepositoryDetailSupplement`）・`MockRepositoryDetailFailure`
  （`AppException`、`RequestCancelledException`をコンストラクタで拒否する
  ガード込み）。`gate`による決定的遅延・cancel優先も同じ。
- 専用fixtureファイルは追加しない。本Issueのテストは直接
  `RepositoryDetailSupplement`を組み立てれば足り、`#85`以降で
  Provider・Page向けfixtureが必要になった時点で追加する
  （現時点で複数テストにまたがる再利用の実需がない）。

### barrel export

- `infrastructure_github.dart`へ`GitHubRepositoryDetailRepository`のみ追加
  （DTO・例外変換関数は既存Search実装と同じく非公開実装詳細のまま）。
- `infrastructure_mock.dart`へ`MockRepositoryDetailRepository`・
  `MockRepositoryDetailResponse`系を追加。

## テスト

- `RepositoryDetailSupplement`: `==`/`hashCode`（`repository_summary_test.dart`
  と同型）。
- `app_exception_test.dart`へ`RepositoryDetailException`のgroup追加
  （既存3つと同じ形の2テスト）。
- DTOテスト: 正常decode、`subscribers_count`の欠落・null・非数値
  ・malformed JSONでの`FormatException`。
- 例外変換関数テスト: `github_exception_mapper_test.dart`と同じ7ケースを
  `RepositoryDetailException`向けに用意。
- Repository統合テスト: 200・`subscribers_count == 0`、`watchers_count`が
  存在してもレスポンスに含まれる場合に読まない（fixtureへ意図的に
  `watchers_count`と異なる`subscribers_count`を仕込み後者を採用することを
  検証）、malformed JSON、403/429・404・その他4xx/5xx、response前・stream中
  のabort→`RequestCancelledException`、owner/nameのURIエンコード
  （`.`・ハイフン等を含むケースで送信パスを検証）、呼び出し回数。
- Mock Repositoryテスト: 成功・失敗・cancel・遅延・呼出回数記録・
  identityごとの応答分離。
- 実GitHub APIへ接続するテストは作らない。

## 実装手順

1. `packages/domain`: `RepositoryDetailException`追加→テスト→
   `RepositoryDetailSupplement`追加→テスト→`RepositoryDetailRepository`
   追加→`domain.dart`のexport更新。
2. `packages/infrastructure/github`: DTO→テスト→例外変換関数→テスト→
   `GitHubRepositoryDetailRepository`→テスト（URIエンコード・cancel・
   エラー分岐・呼び出し回数を含む）→barrel export更新。
3. `packages/infrastructure/mock`: response model→
   `MockRepositoryDetailRepository`→テスト→barrel export更新。
4. 全体検証（下記）を実行する。
5. `tools/src/package_dependency_checker.dart`・
   `.github/workflows/check_pr.yaml`は許可済み依存・既存testステップの
   ままで変更不要（`infrastructure_github: {domain}`、
   `infrastructure_mock: {domain, foundation}`は既存パッケージへの追加
   実装のみで新規依存が発生しないため）。実装後に差分がないことを確認する。

## テスト観点（全体検証）

- `mise exec -- dart test`を`packages/domain`・
  `packages/infrastructure/github`・`packages/infrastructure/mock`の各
  ディレクトリで実行し全て通る。
- `mise exec -- dart run tools/check_package_dependencies.dart`が通る
  （差分が発生しないことの確認）。
- `mise exec -- dart format --output=none --set-exit-if-changed apps packages
  test tools`、`mise exec -- dart analyze --fatal-infos`、
  `mise exec -- dart tools/sync_sdk_versions.dart --check`が通る。
- 実GitHub APIへ接続するテストが存在しないこと（レビュー観点）。

## 対象外

- Riverpod Provider・`dependency_override`の結線
- 5分cache
- Detail Page・OpenContainer・Deep Link
- Summary項目の再取得・複製
- `docs/technical-decisions.md`の編集
