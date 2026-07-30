import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_bar.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required TextEditingController controller,
  required ValueChanged<String> onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TranslationProvider(
        child: Scaffold(
          body: RepositorySearchBar(controller: controller, onSubmit: onSubmit),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('keyboard submitとsearch buttonタップは同じ内容でonSubmitを呼ぶ', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final submitted = <String>[];

    await _pumpBar(tester, controller: controller, onSubmit: submitted.add);

    await tester.enterText(find.byKey(repositorySearchFieldKey), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.tap(find.byKey(repositorySearchSubmitButtonKey));

    expect(submitted, ['flutter', 'flutter']);
  });
}
