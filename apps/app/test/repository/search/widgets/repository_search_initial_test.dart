import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_initial.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_lottie_message.dart';

Future<void> _pumpInitial(WidgetTester tester) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: TranslationProvider(
          child: const Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: RepositorySearchInitial(),
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
  testWidgets('initial専用Lottieと案内文を表示する', (tester) async {
    await _pumpInitial(tester);

    final i18n = AppLocale.ja.translations.repositorySearch;
    expect(find.text(i18n.initialTitle), findsOneWidget);
    expect(find.text(i18n.initialHint), findsOneWidget);

    final message = tester.widget<RepositorySearchLottieMessage>(
      find.byType(RepositorySearchLottieMessage),
    );
    expect(message.assetPath, 'assets/lottie/search_initialize.json');
    expect(message.title, i18n.initialTitle);
    expect(message.description, i18n.initialHint);
  });
}
