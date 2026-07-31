import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/repository/detail/pages/repository_detail_page.dart';

import '../support/fake_repository_detail_repository.dart';

const _flutterIdentity = RepositoryIdentity(owner: 'flutter', name: 'flutter');

const _flutterSummary = RepositorySummary(
  identity: _flutterIdentity,
  ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
  language: 'Dart',
  stargazersCount: 160000,
  forksCount: 27000,
  openIssuesCount: 12000,
);

const _nullLanguageSummary = RepositorySummary(
  identity: RepositoryIdentity(owner: 'octocat', name: 'no-language-repo'),
  ownerAvatarUrl: 'https://example.invalid/avatars/octocat.png',
  language: null,
  stargazersCount: 1,
  forksCount: 0,
  openIssuesCount: 0,
);

const _longNameSummary = RepositorySummary(
  identity: RepositoryIdentity(
    owner: 'an-organization-with-an-unusually-long-account-name',
    name: 'a-repository-with-an-equally-unusually-long-descriptive-name',
  ),
  ownerAvatarUrl: 'https://example.invalid/avatars/long-name-owner.png',
  language: 'Dart',
  stargazersCount: 42,
  forksCount: 7,
  openIssuesCount: 1,
);

const _brokenAvatarSummary = RepositorySummary(
  identity: RepositoryIdentity(owner: 'broken-avatar', name: 'sample-repo'),
  ownerAvatarUrl: 'https://owner-icon.invalid/missing-avatar.png',
  language: 'Dart',
  stargazersCount: 9,
  forksCount: 2,
  openIssuesCount: 0,
);

const _supplement = RepositoryDetailSupplement(
  identity: _flutterIdentity,
  subscribersCount: 9999,
);

final _watcherRetryButton = find.byKey(repositoryDetailWatcherRetryButtonKey);

Future<void> _pumpDetailPage(
  WidgetTester tester, {
  required RepositorySummary summary,
  required FakeRepositoryDetailRepository repository,
  double width = 402,
  AppLocale locale = AppLocale.ja,
  Brightness brightness = Brightness.light,
  double textScaleFactor = 1,
}) async {
  final previousLocale = LocaleSettings.currentLocale;
  addTearDown(() => LocaleSettings.setLocale(previousLocale));
  await LocaleSettings.setLocale(locale);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryDetailRepositoryProvider.overrideWith((ref) => repository),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: brightness,
            ),
          ),
          home: RepositoryDetailPage(summary: summary),
        ),
      ),
    ),
  );
}

void main() {
  group('RepositoryDetailPage', () {
    testWidgets('Provider未完了でも初回frameにSummary6項目が表示される', (tester) async {
      final gate = Completer<void>();
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _flutterIdentity,
          supplement: _supplement,
          gate: gate,
        );

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
      );
      await tester.pump();

      expect(find.text(_flutterSummary.identity.fullName), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('160,000'), findsOneWidget);
      expect(find.text('27,000'), findsOneWidget);
      expect(find.text('12,000'), findsOneWidget);
      expect(find.byType(SkeletonText), findsOneWidget);
      expect(tester.takeException(), isNull);

      gate.complete();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('WatcherだけがSkeletonから実データへ差し替わる', (tester) async {
      final gate = Completer<void>();
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _flutterIdentity,
          supplement: _supplement,
          gate: gate,
        );

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
      );
      await tester.pump();

      expect(find.byType(SkeletonText), findsOneWidget);
      expect(find.text('9,999'), findsNothing);

      // Watcher行のlabelは全状態で存在し続ける安定アンカーのため、その位置・
      // 高さがsuccess前後で変化しないことを直接確認する
      // （完了条件「success時にWatcherだけ差し替わりlayoutが跳ねない」）。
      final labelRectBefore = tester.getRect(find.text('Watcher数'));

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(SkeletonText), findsNothing);
      expect(find.text('9,999'), findsOneWidget);
      expect(tester.getRect(find.text('Watcher数')), labelRectBefore);
      // Watcher以外のSummary項目はsuccess後も表示され続ける。
      expect(find.text(_flutterSummary.identity.fullName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('watchers_countと異なる値でもsubscribersCountを正しく表示する', (
      tester,
    ) async {
      const distinctSupplement = RepositoryDetailSupplement(
        identity: _flutterIdentity,
        subscribersCount: 321,
      );
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _flutterIdentity,
          supplement: distinctSupplement,
        );

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('321'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error時もSummaryが残りWatcher行からRetryできる', (tester) async {
      final repository = FakeRepositoryDetailRepository()
        ..setFailure(
          identity: _flutterIdentity,
          exception: const RepositoryDetailException(),
        );

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(_flutterSummary.identity.fullName), findsOneWidget);
      expect(_watcherRetryButton, findsOneWidget);
      expect(repository.calls, [_flutterIdentity]);

      repository.setSuccess(
        identity: _flutterIdentity,
        supplement: _supplement,
      );
      await tester.tap(_watcherRetryButton);
      await tester.pump();
      await tester.pump();

      expect(find.text('9,999'), findsOneWidget);
      expect(find.text(_flutterSummary.identity.fullName), findsOneWidget);
      expect(repository.calls, [_flutterIdentity, _flutterIdentity]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('狭幅・大text scaleでもerror行がoverflowしない', (tester) async {
      // Watcher行はerror時にRetry用IconButton（48px min）が追加され、
      // Skeleton・data表示より横幅を要求する最も密な状態になる。狭幅・大
      // text scaleの組み合わせで最もoverflowしやすい経路を確認する。
      final repository = FakeRepositoryDetailRepository()
        ..setFailure(
          identity: _flutterIdentity,
          exception: const RepositoryDetailException(),
        );

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
        textScaleFactor: 2,
      );
      await tester.pump();
      await tester.pump();

      expect(_watcherRetryButton, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner iconの読み込みに失敗してもfallback avatarへ切り替わる', (tester) async {
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _brokenAvatarSummary.identity,
          supplement: _supplement,
        );

      await _pumpDetailPage(
        tester,
        summary: _brokenAvatarSummary,
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('languageがnullの場合は未設定を表示する', (tester) async {
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _nullLanguageSummary.identity,
          supplement: _supplement,
        );

      await _pumpDetailPage(
        tester,
        summary: _nullLanguageSummary,
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('未設定'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('長い名前でもoverflowせずに折り返す', (tester) async {
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _longNameSummary.identity,
          supplement: _supplement,
        );

      await _pumpDetailPage(
        tester,
        summary: _longNameSummary,
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    for (final locale in [AppLocale.ja, AppLocale.en]) {
      testWidgets('${locale.name}ロケールでoverflowなく表示する', (tester) async {
        final repository = FakeRepositoryDetailRepository()
          ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

        await _pumpDetailPage(
          tester,
          summary: _flutterSummary,
          repository: repository,
          locale: locale,
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text(locale == AppLocale.ja ? 'スター数' : 'Stars'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in [402.0, 744.0, 1024.0]) {
      testWidgets('幅${width}pxでoverflowなく表示する', (tester) async {
        final repository = FakeRepositoryDetailRepository()
          ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

        await _pumpDetailPage(
          tester,
          summary: _flutterSummary,
          repository: repository,
          width: width,
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('text scaleを拡大してもoverflowなく表示する', (tester) async {
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
        textScaleFactor: 2,
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('$brightnessでもoverflowなく表示する', (tester) async {
        final repository = FakeRepositoryDetailRepository()
          ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

        await _pumpDetailPage(
          tester,
          summary: _flutterSummary,
          repository: repository,
          brightness: brightness,
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('SkeletonをSemanticsで読み上げない', (tester) async {
      final handle = tester.ensureSemantics();
      final gate = Completer<void>();
      final repository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: _flutterIdentity,
          supplement: _supplement,
          gate: gate,
        );

      await _pumpDetailPage(
        tester,
        summary: _flutterSummary,
        repository: repository,
      );
      await tester.pump();

      // SkeletonText自身はExcludeSemantics内部にあるため独自のSemanticsNodeを
      // 持たず、getSemanticsは最も近い祖先（Watcher行のlabel）へfallbackする。
      // Skeleton自体が値のような文字列を読み上げに追加していないことを、
      // 取得できたlabelに数字が含まれないことで確認する。
      final skeletonSemantics = tester.getSemantics(
        find.byType(SkeletonText),
      );
      expect(skeletonSemantics.label, isNot(matches(RegExp(r'\d'))));

      gate.complete();
      await tester.pump();
      await tester.pump();
      handle.dispose();
    });
  });
}
