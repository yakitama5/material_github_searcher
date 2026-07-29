# Issue #68 手書きRiverpod ProviderとComposition Root基盤

Issue: <https://github.com/yakitama5/material_github_searcher/issues/68>

## 目的

Riverpod generatorを導入せず、Application層のProviderを通常起動・Widget Test・
Patrolから同じComposition Root経由で利用できる基盤を追加する。

## 方針

- `packages/application`はFlutterへ依存させず、`package:riverpod`でProviderを
  手書きする。
- Flutter Widget側だけが`package:flutter_riverpod`を利用し、`createApp`を
  `ProviderScope`で包む。
- `createApp`は`List<Override>`を任意に受け取り、通常起動ではProduction、Patrolでは
  Mockのoverrideセットを明示的に渡す。
- `packages/dependency_override`はProduction/Mockのoverrideセットを公開する。
  現時点では結線対象のRepositoryがないため、どちらも空のリストを返す。
- 実ドメイン契約が存在しない段階で、基盤確認だけを目的とした架空のProviderは
  本番コードへ追加しない。ApplicationのUnit TestではテストローカルなProviderを使い、
  `ProviderContainer`とoverride機構を検証する。
- Riverpod generator、annotation、生成ファイルは追加しない。

## 実装手順

1. Riverpod 3.4.2を固定バージョンで各対象packageへ追加し、workspace lockを更新する。
2. dependency overrideのProduction/Mock公開関数とbarrel exportを追加する。
3. `createApp`へoverride引数と`ProviderScope`を追加し、通常起動とPatrolの注入経路を
   更新する。
4. Application Unit TestとWidget Testを追加し、Check PRでApplication Testを実行する。
5. `docs/ARCHITECTURE.md`と`docs/testing.md`へ採用方針・利用パターンを追記する。
6. format、analyze、対象テスト、package依存チェックを実行する。

## テスト観点

- `ProviderContainer`を生成・破棄できる。
- 手書きProviderの値をoverrideして取得できる。
- `createApp`へ渡したoverrideが`ProviderScope`へ反映される。
- overrideなし、Production override、Mock overrideの各経路でアプリが起動する。
- 既存のFlavor、Slang、Widget Test、Patrolの起動契約を維持する。
- Application packageがFlutter SDKやgenerator関連dependencyへ依存しない。

## 対象外

- Repository、API通信、キャッシュ、共通Loading/Error処理の実装
- 画面固有ViewModel、Theme Provider、画面ルーティング
- `docs/technical-decisions.md`の編集
