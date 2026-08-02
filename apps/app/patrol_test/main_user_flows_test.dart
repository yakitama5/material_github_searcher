import 'dart:async';

import 'package:dependency_override/dependency_override.dart';
import 'package:dependency_override/testing.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/repository/detail/pages/repository_detail_page.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_skeleton.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_bar.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_empty.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_initial.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_lottie_message.dart';
import 'package:material_github_searcher/src/repository/search/widgets/search_history_suggestions.dart';
import 'package:material_github_searcher/src/settings/pages/settings_screen.dart';
import 'package:patrol/patrol.dart';

import 'support/main_flow_fixtures.dart';
import 'support/pump_test_app.dart';

const _patrolConfig = PatrolTesterConfig(
  existsTimeout: Duration(seconds: 20),
  visibleTimeout: Duration(seconds: 20),
  settlePolicy: SettlePolicy.noSettle,
  printLogs: true,
);

Future<void> _waitUntilVisible(PatrolIntegrationTester $, Finder finder) async {
  final patrolFinder = $(finder);
  await patrolFinder.waitUntilVisible();
  expect(patrolFinder, findsWidgets);
}

Future<void> _waitUntilExists(PatrolIntegrationTester $, Finder finder) async {
  final patrolFinder = $(finder);
  await patrolFinder.waitUntilExists();
  expect(patrolFinder, findsWidgets);
}

Future<void> _waitForInitialState(PatrolIntegrationTester $) async {
  final i18n = AppLocale.ja.translations.repositorySearch;
  final initial = find.byType(RepositorySearchInitial);
  await _waitUntilVisible($, initial);
  await _waitUntilExists(
    $,
    find.descendant(
      of: initial,
      matching: find.byType(RepositorySearchLottieMessage),
    ),
  );
  await _waitUntilVisible($, find.text(i18n.initialTitle));
  await _waitUntilVisible($, find.text(i18n.initialHint));
}

Future<void> _waitForRepository(
  PatrolIntegrationTester $,
  RepositorySummary summary,
) async {
  final row = find.bySemanticsLabel(patrolRepositorySemanticsLabel(summary));
  await _waitUntilVisible($, row);
  final avatar = find.descendant(of: row, matching: find.byType(Image));
  await _waitUntilExists($, avatar);
}

Future<void> _waitUntilScrollAtStart(
  PatrolIntegrationTester $,
  ScrollableState scrollableState,
) async {
  final deadline = $.tester.binding.clock.now().add(
    const Duration(seconds: 20),
  );
  while (scrollableState.position.pixels >
          scrollableState.position.minScrollExtent + 0.5 ||
      scrollableState.position.isScrollingNotifier.value) {
    if ($.tester.binding.clock.now().isAfter(deadline)) {
      fail(
        'Scroll view did not reach its start: '
        'pixels=${scrollableState.position.pixels}, '
        'min=${scrollableState.position.minScrollExtent}',
      );
    }
    await $.pump(const Duration(milliseconds: 100));
  }
}

void _setSearchResponse(
  MockOverrideSet mocks, {
  required RepositorySearchQuery query,
  required RepositorySearchPage page,
  int pageNumber = 1,
  Completer<void>? gate,
}) {
  mocks.searchRepository.setResponse(
    query: query,
    page: pageNumber,
    response: MockRepositorySearchSuccess(page, gate: gate),
  );
}

void _setDetailResponse(
  MockOverrideSet mocks, {
  Completer<void>? gate,
}) {
  mocks.detailRepository.setResponse(
    identity: patrolPrimaryRepository.identity,
    response: MockRepositoryDetailSuccess(
      patrolDetailSupplement,
      gate: gate,
    ),
  );
}

void main() {
  patrolTest(
    '起動して検索し、API完了前に詳細を開いてRepository情報を確認する',
    ($) async {
      final mocks = createMockOverrideSet();
      final searchGate = Completer<void>();
      final detailGate = Completer<void>();
      _setSearchResponse(
        mocks,
        query: patrolSearchQuery,
        page: patrolInitialSearchPage,
        gate: searchGate,
      );
      _setDetailResponse(mocks, gate: detailGate);

      await pumpTestApp($, overrides: mocks.overrides);

      expect(AppBuildConfig.current.flavor, Flavor.dev);
      expect(LocaleSettings.currentLocale, AppLocale.ja);
      await _waitForInitialState($);

      await $(repositorySearchFieldKey).enterText(patrolSearchQuery.value);
      await $(repositorySearchSubmitButtonKey).tap();
      await _waitUntilExists($, find.byType(RepositoryListSkeleton));
      expect(searchGate.isCompleted, isFalse);

      searchGate.complete();
      await $.pump();
      await _waitForRepository($, patrolPrimaryRepository);

      final primaryRow = find.bySemanticsLabel(
        patrolRepositorySemanticsLabel(patrolPrimaryRepository),
      );
      await $(primaryRow).tap();
      await _waitUntilVisible($, find.byType(RepositoryDetailPage));
      await _waitUntilVisible(
        $,
        find.text(patrolPrimaryRepository.identity.fullName),
      );
      await _waitUntilVisible($, find.text('Dart'));
      await _waitUntilExists($, find.byType(SkeletonText));
      expect(detailGate.isCompleted, isFalse);
      expect(mocks.detailRepository.callCount, 1);

      expect(find.text('160,000'), findsOneWidget);
      expect(find.text('27,000'), findsOneWidget);
      expect(find.text('12,000'), findsOneWidget);
      expect(find.text('$patrolSubscribersCount'), findsNothing);

      detailGate.complete();
      await $.pump();
      await _waitUntilVisible($, find.text('$patrolSubscribersCount'));
      expect(find.byType(SkeletonText), findsNothing);

      await $(find.byType(BackButton)).tap();
      await _waitForRepository($, patrolPrimaryRepository);
    },
    config: _patrolConfig,
  );

  patrolTest(
    '無限scroll、Pull to Refresh、0件検索を利用者操作で確認する',
    ($) async {
      final mocks = createMockOverrideSet();
      final pageTwoGate = Completer<void>();
      _setSearchResponse(
        mocks,
        query: patrolSearchQuery,
        page: patrolInitialSearchPage,
      );
      _setSearchResponse(
        mocks,
        query: patrolSearchQuery,
        page: patrolSecondSearchPage,
        pageNumber: 2,
        gate: pageTwoGate,
      );

      await pumpTestApp($, overrides: mocks.overrides);
      await _waitForInitialState($);
      await $(repositorySearchFieldKey).enterText(patrolSearchQuery.value);
      await $(repositorySearchSubmitButtonKey).tap();
      await _waitForRepository($, patrolPrimaryRepository);

      final scrollable = find.byType(CustomScrollView);
      final lastInitialRow = find.bySemanticsLabel(
        patrolRepositorySemanticsLabel(patrolInitialSearchPage.items.last),
      );
      await $(lastInitialRow).scrollTo(view: scrollable, maxScrolls: 30);
      await _waitUntilExists($, find.byType(RepositoryListItemSkeleton));
      expect(
        mocks.searchRepository.calls.where((call) => call.page == 2).length,
        1,
      );

      pageTwoGate.complete();
      await $.pump();
      await _waitForRepository($, patrolPageTwoRepository);

      final scrollableStateFinder = find.descendant(
        of: scrollable,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      final scrollableState = $.tester.state<ScrollableState>(
        scrollableStateFinder,
      );
      await $.tester.fling(scrollable, const Offset(0, 5000), 1000);
      await _waitUntilScrollAtStart($, scrollableState);

      final refreshGate = Completer<void>();
      _setSearchResponse(
        mocks,
        query: patrolSearchQuery,
        page: patrolRefreshSearchPage,
        gate: refreshGate,
      );
      final refreshingLabel =
          AppLocale.ja.translations.repositorySearch.refreshing;
      final pullDistance = scrollableState.position.viewportDimension * 0.45;
      await $.tester.timedDrag(
        scrollable,
        Offset(0, pullDistance),
        const Duration(milliseconds: 300),
      );
      await _waitUntilExists($, find.bySemanticsLabel(refreshingLabel));
      await _waitUntilExists($, find.byKey(m3RefreshIndicatorGlyphKey));
      expect(refreshGate.isCompleted, isFalse);

      refreshGate.complete();
      await $.pump();
      await _waitForRepository($, patrolRefreshedRepository);
      expect(
        find.bySemanticsLabel(
          patrolRepositorySemanticsLabel(patrolPrimaryRepository),
        ),
        findsNothing,
      );

      _setSearchResponse(
        mocks,
        query: patrolEmptyQuery,
        page: patrolEmptySearchPage,
      );
      await $(repositorySearchFieldKey).enterText(patrolEmptyQuery.value);
      await $(repositorySearchSubmitButtonKey).tap();
      final empty = find.byType(RepositorySearchEmpty);
      await _waitUntilVisible($, empty);
      await _waitUntilExists(
        $,
        find.descendant(
          of: empty,
          matching: find.byType(RepositorySearchLottieMessage),
        ),
      );
      await _waitUntilVisible(
        $,
        find.text(AppLocale.ja.translations.repositorySearch.emptyTitle),
      );
      await _waitUntilVisible(
        $,
        find.text(AppLocale.ja.translations.repositorySearch.emptyHint),
      );
    },
    config: _patrolConfig,
  );

  patrolTest(
    '再検索、履歴サジェスト、Settings、Licenseの遷移を確認する',
    ($) async {
      final mocks = createMockOverrideSet();
      _setSearchResponse(
        mocks,
        query: patrolSearchQuery,
        page: patrolInitialSearchPage,
      );

      await pumpTestApp($, overrides: mocks.overrides);
      await _waitForInitialState($);
      await $(repositorySearchFieldKey).enterText(patrolSearchQuery.value);
      await $(repositorySearchSubmitButtonKey).tap();
      await _waitForRepository($, patrolPrimaryRepository);

      await $(repositorySearchFieldKey).tap();
      await _waitUntilExists(
        $,
        find.byKey(repositorySearchHistorySuggestionsKey),
      );
      final suggestion = find.byKey(
        repositorySearchHistorySuggestionItemKey(patrolSearchQuery.value),
      );
      await _waitUntilVisible($, suggestion);
      await $(suggestion).tap();
      await _waitForRepository($, patrolPrimaryRepository);
      expect(
        mocks.searchRepository.calls
            .where((call) => call.query == patrolSearchQuery)
            .length,
        2,
      );

      await $(Icons.settings).tap();
      await _waitUntilVisible($, find.byKey(settingsLicensesListTileKey));

      await $(settingsLicensesListTileKey).tap();
      await _waitUntilVisible($, find.byType(LicensePage));
      await _waitUntilVisible(
        $,
        find.text(AppLocale.ja.translations.settings.licensesTitle),
      );
      await _waitUntilVisible($, find.text(AppBuildConfig.current.appName));

      await $(find.byType(BackButton)).tap();
      await _waitUntilVisible($, find.byKey(settingsLicensesListTileKey));
    },
    config: _patrolConfig,
  );
}
