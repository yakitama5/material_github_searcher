import 'package:application/application.dart';
import 'package:infrastructure_github/infrastructure_github.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:infrastructure_shared_preferences/infrastructure_shared_preferences.dart';
import 'package:riverpod/misc.dart';

/// テスト・開発用のMock実装とProvider overrideをひとまとめにした設定。
///
/// [createMockOverrides]はこれまでどおり新しいMockを生成した
/// [List<Override>]だけを返す。一方、Patrolのようにシナリオごとに決定的な
/// 応答を設定する呼び出し元は本型を使うことで、`apps/app`から
/// `infrastructure_mock`を直接参照せずに同じMockインスタンスを設定できる。
final class MockOverrideSet {
  /// 指定されたMock、または未指定なら新しいMockで設定を生成する。
  MockOverrideSet({
    MockRepositorySearchRepository? searchRepository,
    MockRepositoryDetailRepository? detailRepository,
    MockSearchHistoryRepository? searchHistoryRepository,
    MockThemeSettingsRepository? themeSettingsRepository,
  }) : searchRepository = searchRepository ?? MockRepositorySearchRepository(),
       detailRepository = detailRepository ?? MockRepositoryDetailRepository(),
       searchHistoryRepository =
           searchHistoryRepository ?? MockSearchHistoryRepository(),
       themeSettingsRepository =
           themeSettingsRepository ?? MockThemeSettingsRepository();

  /// 検索RepositoryのMock。
  final MockRepositorySearchRepository searchRepository;

  /// Detail RepositoryのMock。
  final MockRepositoryDetailRepository detailRepository;

  /// 検索履歴のメモリ上Fake。
  final MockSearchHistoryRepository searchHistoryRepository;

  /// テーマ設定のメモリ上Fake。
  final MockThemeSettingsRepository themeSettingsRepository;

  /// `createApp()`へ渡すProvider override一式。
  List<Override> get overrides => [
    repositorySearchRepositoryProvider.overrideWith(
      (ref) => searchRepository,
    ),
    repositoryDetailRepositoryProvider.overrideWith((ref) => detailRepository),
    searchHistoryRepositoryProvider.overrideWith(
      (ref) => searchHistoryRepository,
    ),
    themeSettingsRepositoryProvider.overrideWith(
      (ref) => themeSettingsRepository,
    ),
  ];
}

/// シナリオごとに設定可能なMock override setを生成する。
MockOverrideSet createMockOverrideSet() => MockOverrideSet();

/// 本番環境向けのProvider override一式を生成する。
///
/// Repository検索は実GitHub APIを叩く[GitHubRepositorySearchRepository]へ
/// 結線する。`Dio`は`createGitHubDio`が本番向けに生成し、Providerが初めて
/// 参照された時点で遅延生成する。Provider dispose時に`Dio.close`でHTTP
/// clientを解放し、socketの残留を防ぐ。
///
/// Repository Detailも同様に[GitHubRepositoryDetailRepository]へ結線し、
/// 検索とは別の`Dio`インスタンスをProviderごとに遅延生成・dispose時にcloseする。
///
/// 検索履歴は[SharedPreferencesSearchHistoryRepository]へ結線する。
/// `SharedPreferencesAsync`はkey単位で直接読み書きするだけで、アプリ起動時に
/// 全件を読み込むキャッシュや`main.dart`側のグローバル状態を必要としない
/// ため、Repository検索と同様Providerが初めて参照された時点で生成する。
/// `createSharedPreferencesAsync`自体は`preferencesFactory`として渡し、
/// [SharedPreferencesSearchHistoryRepository]の`load`・`save`呼び出しごとに
/// 遅延実行させる（platform未登録時の生成失敗もRepositoryのtry節で
/// 永続化失敗として変換できるようにするため）。
///
/// テーマ設定も同じ`infrastructure_shared_preferences`packageの
/// [SharedPreferencesThemeSettingsRepository]へ結線し、検索履歴とは独立した
/// keyへ保存する。
List<Override> createProductionOverrides() => [
  repositorySearchRepositoryProvider.overrideWith((ref) {
    final dio = createGitHubDio();
    ref.onDispose(dio.close);
    return GitHubRepositorySearchRepository(dio: dio);
  }),
  repositoryDetailRepositoryProvider.overrideWith((ref) {
    final dio = createGitHubDio();
    ref.onDispose(dio.close);
    return GitHubRepositoryDetailRepository(dio: dio);
  }),
  searchHistoryRepositoryProvider.overrideWith(
    (ref) => const SharedPreferencesSearchHistoryRepository(
      preferencesFactory: createSharedPreferencesAsync,
    ),
  ),
  themeSettingsRepositoryProvider.overrideWith(
    (ref) => const SharedPreferencesThemeSettingsRepository(
      preferencesFactory: createSharedPreferencesAsync,
    ),
  ),
];

/// テスト・開発環境向けのProvider override一式を生成する。
///
/// Repository検索は決定的な[MockRepositorySearchRepository]へ結線し、実APIへ
/// 接続せず同じシナリオ（成功・空・失敗・遅延・cancel）を再現できるように
/// する。Repository Detailも同様に[MockRepositoryDetailRepository]へ結線する。
/// 検索履歴も同様に、実ストレージへ書き込まない
/// [MockSearchHistoryRepository]へ結線する。テーマ設定も同様に、実ストレージへ
/// 書き込まない[MockThemeSettingsRepository]へ結線する。
List<Override> createMockOverrides() => [
  ...createMockOverrideSet().overrides,
];
