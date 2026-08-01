import 'package:designsystem/designsystem.dart';
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

String get _expectedSemanticsLabel {
  final i18n = AppLocale.ja.translations.repositorySearch;
  return '${_flutterRepo.identity.fullName}, ${i18n.languageLabel}: '
      '${_flutterRepo.language}';
}

void main() {
  testWidgets('補足情報は言語だけを表示しStarを表示しない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TranslationProvider(
          child: Scaffold(body: RepositoryListItem(summary: _flutterRepo)),
        ),
      ),
    );

    expect(find.byIcon(Icons.code), findsOneWidget);
    expect(find.byType(MetaInfoRow), findsOneWidget);
    expect(find.text('${_flutterRepo.language}'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('${_flutterRepo.stargazersCount}'), findsNothing);
  });

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

  testWidgets('onTapを渡した場合はSemanticsもtap操作可能なbuttonとして公開する', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: TranslationProvider(
          child: Scaffold(
            body: RepositoryListItem(summary: _flutterRepo, onTap: (_) {}),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(RepositoryListItem)),
      matchesSemantics(
        label: _expectedSemanticsLabel,
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('onTapを渡さない場合はSemanticsもbutton・tap操作を公開しない', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: TranslationProvider(
          child: const Scaffold(
            body: RepositoryListItem(summary: _flutterRepo),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(RepositoryListItem)),
      matchesSemantics(label: _expectedSemanticsLabel),
    );
    handle.dispose();
  });
}
