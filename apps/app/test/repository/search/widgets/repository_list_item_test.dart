import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_item.dart';

const _flutterRepo = RepositorySummary(
  identity: RepositoryIdentity(owner: 'flutter', name: 'flutter'),
  ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
  language: 'Dart',
  stargazersCount: 160000,
  forksCount: 27000,
  openIssuesCount: 12000,
);

void main() {
  testWidgets('タップ時に指定したcallbackへidentityを渡す', (tester) async {
    RepositoryIdentity? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: TranslationProvider(
          child: Scaffold(
            body: RepositoryListItem(
              summary: _flutterRepo,
              onTap: (identity) => tapped = identity,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ListTile));
    await tester.pump();

    expect(tapped, _flutterRepo.identity);
  });

  testWidgets('onTapを渡さない場合はタップ操作を受け付けない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TranslationProvider(
          child: const Scaffold(
            body: RepositoryListItem(summary: _flutterRepo),
          ),
        ),
      ),
    );

    final listTile = tester.widget<ListTile>(find.byType(ListTile));
    expect(listTile.onTap, isNull);
  });
}
