# Issue #74 GitHub Repository Search APIアダプターを追加する

Issue: <https://github.com/yakitama5/material_github_searcher/issues/74>

## 目的

`#73`（コミット`f0ddff2`）で追加済みのRepository検索Domain契約
（`RepositorySearchRepository`等）を満たす実装として、GitHub REST
`GET /search/repositories`を叩く`infrastructure_github`パッケージを追加する。
APIキーなしで動作し、リクエスト単位のcancelとRate Limit分類へ対応する。

## Issue原文からの変更点

Issue原文は`http: 1.6.0`（`Client.send`/`AbortableRequest`）を前提に書かれて
いるが、次の2点をユーザー指示により変更する。

1. `http`ではなく`dio`（5.11.0固定）を通信クライアントとして採用する。
2. HTTP・decode・Rate Limit・404・cancelの例外変換ロジックは、
   `infrastructure_github`内に閉じた1関数（`mapDioExceptionToAppException`）
   として実装する。他packageへは切り出さない。将来Detail API等の別adapterが
   増えた時点で共通化を再検討する。

## スコープ境界（重要）

`packages/dependency_override`は今回変更しない。Issue本文「対応内容」
チェックリストにdependency_overrideの変更は含まれておらず、「対象外」に
明記の"Riverpod Provider"は禁止スコープに含まれる。`RepositorySearchRepository`
を注入するProviderが`application`側にまだ存在しないため、override対象が無い
状態で結線コードだけ足しても空のoverrideにしかならない。本Issueは
`createGitHubDio()`という本番用Dio生成ファクトリを提供するところまでとし、
Provider追加とその結線は後続Issueに委ねる。

`dependency_override`、`docs/technical-decisions.md`、Riverpod Providerは
変更しない。generator・ViewModelも使用しない。

## 方針

### パッケージ構成

```text
packages/infrastructure/github/
├── pubspec.yaml                                 # dio: 5.11.0固定、domain依存のみ
├── lib/
│   ├── infrastructure_github.dart               # barrel export
│   └── src/
│       ├── dto/
│       │   ├── github_search_response_dto.dart
│       │   └── github_search_item_dto.dart
│       ├── client/
│       │   └── github_dio_factory.dart          # createGitHubDio()
│       ├── error/
│       │   └── github_exception_mapper.dart     # mapDioExceptionToAppException()
│       └── repository/
│           └── github_repository_search_repository.dart
└── test/
    ├── dto/github_search_response_dto_test.dart
    ├── dto/github_search_item_dto_test.dart
    ├── client/github_dio_factory_test.dart
    ├── error/github_exception_mapper_test.dart
    ├── repository/github_repository_search_repository_test.dart
    └── support/fake_http_client_adapter.dart    # 自前Fake（対称パス対象外）
```

`pubspec.yaml`は`packages/infrastructure/mock/pubspec.yaml`を踏襲する。
`meta`は追加しない（DTOは非公開実装詳細のためfinal+コンストラクタで十分）。

### DTO

`Dio`既定の`ResponseType.json`を使い、JSON decode自体はdioに任せる
（malformed JSONはdioが`DioException`として検出し、例外変換関数側で拾う）。
DTOの`fromJson(Map<String, dynamic>)`は「型の合ったMapを受け取った後の
手書きdecode」を担当する。

- `GithubSearchResponseDto`: `totalCount`（`total_count`, int必須）、
  `items`（`List`必須、各要素を`GithubSearchItemDto.fromJson`へ委譲）。
- `GithubSearchItemDto`: `full_name`を`owner`/`name`へ分解（`/`を含まない値は
  不正としてエラー）、`owner.avatar_url`（ネストMapの型検証込み）、`language`
  （唯一nullable、キー欠落・null値の両方を許容）、`stargazers_count`/
  `forks_count`/`open_issues_count`（int必須）。`watchers_count`は読み取らない。
  `toDomain()`で`RepositorySummary`へ変換する。
- 必須フィールド欠落・型不正は、フィールド名を含む`FormatException`を投げる
  共通ヘルパー（`T _requireField<T>(json, key)`）で統一する。

### `GitHubRepositorySearchRepository`

- コンストラクタで`Dio`を注入する（Repository内部でDioを生成しない。本番用
  生成は`createGitHubDio()`に分離）。
- `search()`冒頭で`cancellationToken.throwIfCancelled()`を呼び、既にキャンセル
  済みなら通信を開始しない。次に`CancelToken()`を生成し、
  `cancellationToken.whenCancelled.then((_) => cancelToken.cancel())`で接続する
  （`await`しないことが重要。awaitすると正常完了を待ってしまいcancelが効かなく
  なる。`whenCancelled`は完了済みなら即完了するFutureを返す契約のため、
  リクエスト開始前キャンセルもこの一箇所で自然にカバーされる）。
- `_dio.get<Map<String, dynamic>>('/search/repositories', queryParameters:
  {'q': query.value, 'page': page, 'per_page': perPage}, cancelToken:
  cancelToken)`。`q`のURLエンコードはdioの`queryParameters`機構に任せる。
  `sort`/`order`は指定しない（Best Match順）。
- `hasMore = items.isNotEmpty && (page * perPage) < min(totalCount, 1000)`、
  `nextPage: hasMore ? page + 1 : null`という単一の式から両方を導出し、
  `RepositorySearchPage`コンストラクタの不変条件違反を構造的に防ぐ。
- 例外処理: `on DioException catch (e, st)` →
  `mapDioExceptionToAppException(e)`の結果を`Error.throwWithStackTrace`で
  再送出。`on FormatException catch (e, st)` → `RepositorySearchException`へ
  同様に変換。その他は`UnknownException`。

### 例外変換関数（`mapDioExceptionToAppException`）

例外を投げない純粋関数として実装する（`AppException`を返すだけ。呼び出し元が
`Error.throwWithStackTrace`で元のスタックトレースを付けて投げ直す）。

- `DioExceptionType.cancel` → `RequestCancelledException()`
- `statusCode == 403 || 429` → `RepositorySearchException`（messageに
  `x-ratelimit-remaining`/`x-ratelimit-reset`ヘッダー値を含める）
- `statusCode == 404` → `RepositorySearchException`
- その他のstatusCode → `RepositorySearchException`
- レスポンス自体を受け取れない場合（timeout、malformed JSONによるdio自身の
  decode失敗等）→ `RepositorySearchException`

`domain`の`AppException`系は変更しない（サブタイプ追加はIssue「後続への
引き継ぎ」の「Rate Limit・cancelの例外型を後続で再定義しない」と矛盾するため
不採用）。

### テスト

- `test/support/fake_http_client_adapter.dart`: `Dio`の`HttpClientAdapter`
  インターフェースを自前実装したFake（外部モックパッケージは追加しない）。
  `capturedRequests`でリクエスト内容を検証し、`fetch()`の`cancelFuture`引数で
  「response前のabort」「stream中のabort」を制御する。
- DTOテスト: 正常decode、0件、複数件、nullable `language`、`full_name`分解、
  必須フィールド欠落・型不正時の`FormatException`。
- 例外変換関数テスト: cancel/403+429（rate limitヘッダー含む）/404/その他
  4xx5xx/レスポンスなし、の分岐を個別に検証。
- Repository統合テスト: 200/0件/複数件/nullable language、query・page・
  per_pageの伝播、ヘッダーのマージ、malformed JSON→`RepositorySearchException`
  （スタックトレース伝播確認）、403/429・404・その他4xx5xx、response前/
  stream中のabort→`RequestCancelledException`、1000件境界（3パターン）、
  呼び出し回数検証。
- 実GitHub APIへ接続するテストは作らない（全テストがFakeAdapter経由）。

## 実装手順

1. `git gtr new <branch>` → `git gtr ai <branch>`で依存追加laneのworktreeを
   作成する（pubspec/lockfileを変更するため）。
2. `packages/infrastructure/github/pubspec.yaml`を新規作成し、ルート
   `pubspec.yaml`の`workspace:`へ追加。`dart pub get`でlockfileを更新する。
3. DTO実装（Item→Response）→対応するUnit Testを先に書く。
4. 例外変換関数`mapDioExceptionToAppException`実装＋テスト。
5. `createGitHubDio()`実装＋ヘッダー検証テスト。
6. `FakeHttpClientAdapter`実装。
7. `GitHubRepositorySearchRepository`実装（リクエスト構築・CancelToken接続・
   hasMore判定・例外変換呼び出し）。
8. Repository統合テストで全ケースを網羅する。
9. `tools/src/package_dependency_checker.dart`の`allowedPackageDependencies`に
   `'infrastructure_github': {'domain'}`を追加し、
   `test/tools/package_dependency_checker_test.dart`の`_workspacePaths`・
   `_packageNames`・`_defaultDependencies`の3箇所を同時に更新する
   （片方だけの更新は既存テストを壊す）。
10. `.github/workflows/check_pr.yaml`の`test`ジョブへ以下を追加する。

    ```yaml
    - name: Test infrastructure_github package
      working-directory: packages/infrastructure/github
      run: dart test
    ```

11. 全体検証（下記）を実行する。

## テスト観点

- `mise exec -- dart test`を`packages/infrastructure/github`で実行し、上記の
  DTO/例外変換/Dioファクトリ/Repository統合テストが全て通る。
- `mise exec -- dart test test/tools`と
  `mise exec -- dart run tools/check_package_dependencies.dart`が通る。
- `mise exec -- dart format --output=none --set-exit-if-changed apps packages
  test tools`、`mise exec -- dart analyze --fatal-infos`、
  `mise exec -- dart tools/sync_sdk_versions.dart --check`が通る。
- 実GitHub APIへ接続するテストが存在しないこと（レビュー観点）。

## 対象外

- APIキー・認証・envied
- 自動Retry
- Riverpod Provider・`dependency_override`の結線
- UI
- Detail API
- `docs/technical-decisions.md`の編集
