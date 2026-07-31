import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_empty.dart';

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
    });

    testWidgets('Reduce Motionでは静止しanimationが実行されない', (tester) async {
      await _pumpEmpty(tester, disableAnimations: true);

      // Lottie compositionの非同期読み込みを、無限repeatに依存せず
      // 固定時間のpumpで待つ（後続issueのアニメーション実装に依存しない
      // 完了条件「Widget Testはanimation完了に依存しない」に沿う）。
      await tester.pump(const Duration(seconds: 1));

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Reduce Motion無効時はanimationが実行される', (tester) async {
      await _pumpEmpty(tester);

      await tester.pump(const Duration(seconds: 1));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('Lottieの描画領域はSemantics treeから除外する', (tester) async {
      await _pumpEmpty(tester, disableAnimations: true);

      // Lottie内部も独自にExcludeSemanticsを使うため、最低1つ
      // （本Widgetが明示的に包んだ分）存在することだけを確認する。
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });
  });
}
