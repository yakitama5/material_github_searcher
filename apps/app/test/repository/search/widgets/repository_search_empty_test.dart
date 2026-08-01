import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_empty.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_lottie_message.dart';

/// 本番と同じ`SliverFillRemaining(hasScrollBody: false)`配下でmountする。
///
/// `hasScrollBody: false`は子にintrinsic dimensionsの計算を要求するため
/// （`repository_search_empty.dart`のdocコメント参照）、素の`Scaffold(body:
/// ...)`ではなくこの構成でテストすることで、本Widgetが将来
/// `LayoutBuilder`等のintrinsic計算不能なWidgetを内包してしまう回帰を
/// このテストだけで検知できるようにする。
Future<void> _pumpEmpty(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: TranslationProvider(
          child: const Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: RepositorySearchEmpty(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('RepositorySearchEmpty', () {
    testWidgets('見出しと補助文を表示する', (tester) async {
      await _pumpEmpty(tester, disableAnimations: true);

      expect(
        find.text(AppLocale.ja.translations.repositorySearch.emptyTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppLocale.ja.translations.repositorySearch.emptyHint),
        findsOneWidget,
      );

      final message = tester.widget<RepositorySearchLottieMessage>(
        find.byType(RepositorySearchLottieMessage),
      );
      expect(message.assetPath, 'assets/lottie/woman_empty_box.json');
      expect(message.reducedMotionProgress, 1);
      expect(message.renderCache, RenderCache.raster);
    });
  });
}
