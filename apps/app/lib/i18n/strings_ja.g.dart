///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsJa = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final i18n = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$ja common = Translations$common$ja.internal(_root);
	late final Translations$repositoryDetail$ja repositoryDetail = Translations$repositoryDetail$ja.internal(_root);
	late final Translations$repositorySearch$ja repositorySearch = Translations$repositorySearch$ja.internal(_root);
	late final Translations$settings$ja settings = Translations$settings$ja.internal(_root);
}

// Path: common
class Translations$common$ja {
	Translations$common$ja.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'ボタンを押した回数'
	String get pushCountLabel => 'ボタンを押した回数';

	/// ja: '追加'
	String get incrementTooltip => '追加';

	late final Translations$common$navigation$ja navigation = Translations$common$navigation$ja.internal(_root);
}

// Path: repositoryDetail
class Translations$repositoryDetail$ja {
	Translations$repositoryDetail$ja.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '言語'
	String get languageLabel => '言語';

	/// ja: '未設定'
	String get languageUnset => '未設定';

	/// ja: 'スター数'
	String get starsLabel => 'スター数';

	/// ja: '${count: decimalPattern}'
	String starsValue({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}';

	/// ja: 'フォーク数'
	String get forksLabel => 'フォーク数';

	/// ja: '${count: decimalPattern}'
	String forksValue({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}';

	/// ja: 'Issue数'
	String get issuesLabel => 'Issue数';

	/// ja: '${count: decimalPattern}'
	String issuesValue({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}';

	/// ja: 'Watcher数'
	String get watchersLabel => 'Watcher数';

	/// ja: '${count: decimalPattern}'
	String watchersValue({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}';

	/// ja: 'Watcher数の取得に失敗しました'
	String get watcherError => 'Watcher数の取得に失敗しました';

	/// ja: '再試行'
	String get retry => '再試行';

	/// ja: 'Watcher数を再取得'
	String get retryTooltip => 'Watcher数を再取得';
}

// Path: repositorySearch
class Translations$repositorySearch$ja {
	Translations$repositorySearch$ja.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'リポジトリ検索'
	String get searchFieldLabel => 'リポジトリ検索';

	/// ja: 'リポジトリ名やキーワードを入力'
	String get searchFieldHint => 'リポジトリ名やキーワードを入力';

	/// ja: '検索する'
	String get searchButtonTooltip => '検索する';

	/// ja: 'キーワードを入力し、キーボードの検索または検索ボタンで検索してください'
	String get guidance => 'キーワードを入力し、キーボードの検索または検索ボタンで検索してください';

	/// ja: '条件に一致するリポジトリが見つかりませんでした'
	String get emptyTitle => '条件に一致するリポジトリが見つかりませんでした';

	/// ja: '別のキーワードで再度検索してください'
	String get emptyHint => '別のキーワードで再度検索してください';

	/// ja: '通信エラーが発生しました。しばらくしてから再度お試しください'
	String get errorGeneric => '通信エラーが発生しました。しばらくしてから再度お試しください';

	/// ja: 'GitHub APIの利用回数上限に達しました。しばらくしてから再度お試しください'
	String get errorRateLimited => 'GitHub APIの利用回数上限に達しました。しばらくしてから再度お試しください';

	/// ja: '再試行'
	String get retry => '再試行';

	/// ja: '更新中'
	String get refreshing => '更新中';

	/// ja: '未設定'
	String get languageUnset => '未設定';

	/// ja: '言語'
	String get languageLabel => '言語';

	/// ja: 'スター数'
	String get starsLabel => 'スター数';

	/// ja: '検索履歴'
	String get historySuggestionsLabel => '検索履歴';

	/// ja: 'すべて削除'
	String get historyClearAllLabel => 'すべて削除';

	/// ja: '検索履歴をすべて削除'
	String get historyClearAllTooltip => '検索履歴をすべて削除';

	/// ja: '検索履歴を削除しますか？'
	String get historyClearAllDialogTitle => '検索履歴を削除しますか？';

	/// ja: '保存されている検索履歴をすべて削除します。この操作は取り消せません。'
	String get historyClearAllDialogMessage => '保存されている検索履歴をすべて削除します。この操作は取り消せません。';

	/// ja: '削除'
	String get historyClearAllDialogConfirm => '削除';

	/// ja: 'キャンセル'
	String get historyClearAllDialogCancel => 'キャンセル';
}

// Path: settings
class Translations$settings$ja {
	Translations$settings$ja.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '設定'
	String get title => '設定';

	/// ja: 'UIスタイル'
	String get uiStyleTitle => 'UIスタイル';

	/// ja: 'システム'
	String get uiStyleSystem => 'システム';

	/// ja: 'Android'
	String get uiStyleAndroid => 'Android';

	/// ja: 'iOS'
	String get uiStyleIos => 'iOS';

	/// ja: 'テーマモード'
	String get themeModeTitle => 'テーマモード';

	/// ja: 'システム'
	String get themeModeSystem => 'システム';

	/// ja: 'ライト'
	String get themeModeLight => 'ライト';

	/// ja: 'ダーク'
	String get themeModeDark => 'ダーク';

	/// ja: '設定の保存に失敗しました'
	String get saveError => '設定の保存に失敗しました';

	/// ja: 'ライセンス'
	String get licensesTitle => 'ライセンス';
}

// Path: common.navigation
class Translations$common$navigation$ja {
	Translations$common$navigation$ja.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '検索'
	String get search => '検索';

	/// ja: '設定'
	String get settings => '設定';
}

/// The flat map containing all translations for locale <ja>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.pushCountLabel' => 'ボタンを押した回数',
			'common.incrementTooltip' => '追加',
			'common.navigation.search' => '検索',
			'common.navigation.settings' => '設定',
			'repositoryDetail.languageLabel' => '言語',
			'repositoryDetail.languageUnset' => '未設定',
			'repositoryDetail.starsLabel' => 'スター数',
			'repositoryDetail.starsValue' => ({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}',
			'repositoryDetail.forksLabel' => 'フォーク数',
			'repositoryDetail.forksValue' => ({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}',
			'repositoryDetail.issuesLabel' => 'Issue数',
			'repositoryDetail.issuesValue' => ({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}',
			'repositoryDetail.watchersLabel' => 'Watcher数',
			'repositoryDetail.watchersValue' => ({required num count}) => '${NumberFormat.decimalPattern('ja').format(count)}',
			'repositoryDetail.watcherError' => 'Watcher数の取得に失敗しました',
			'repositoryDetail.retry' => '再試行',
			'repositoryDetail.retryTooltip' => 'Watcher数を再取得',
			'repositorySearch.searchFieldLabel' => 'リポジトリ検索',
			'repositorySearch.searchFieldHint' => 'リポジトリ名やキーワードを入力',
			'repositorySearch.searchButtonTooltip' => '検索する',
			'repositorySearch.guidance' => 'キーワードを入力し、キーボードの検索または検索ボタンで検索してください',
			'repositorySearch.emptyTitle' => '条件に一致するリポジトリが見つかりませんでした',
			'repositorySearch.emptyHint' => '別のキーワードで再度検索してください',
			'repositorySearch.errorGeneric' => '通信エラーが発生しました。しばらくしてから再度お試しください',
			'repositorySearch.errorRateLimited' => 'GitHub APIの利用回数上限に達しました。しばらくしてから再度お試しください',
			'repositorySearch.retry' => '再試行',
			'repositorySearch.refreshing' => '更新中',
			'repositorySearch.languageUnset' => '未設定',
			'repositorySearch.languageLabel' => '言語',
			'repositorySearch.starsLabel' => 'スター数',
			'repositorySearch.historySuggestionsLabel' => '検索履歴',
			'repositorySearch.historyClearAllLabel' => 'すべて削除',
			'repositorySearch.historyClearAllTooltip' => '検索履歴をすべて削除',
			'repositorySearch.historyClearAllDialogTitle' => '検索履歴を削除しますか？',
			'repositorySearch.historyClearAllDialogMessage' => '保存されている検索履歴をすべて削除します。この操作は取り消せません。',
			'repositorySearch.historyClearAllDialogConfirm' => '削除',
			'repositorySearch.historyClearAllDialogCancel' => 'キャンセル',
			'settings.title' => '設定',
			'settings.uiStyleTitle' => 'UIスタイル',
			'settings.uiStyleSystem' => 'システム',
			'settings.uiStyleAndroid' => 'Android',
			'settings.uiStyleIos' => 'iOS',
			'settings.themeModeTitle' => 'テーマモード',
			'settings.themeModeSystem' => 'システム',
			'settings.themeModeLight' => 'ライト',
			'settings.themeModeDark' => 'ダーク',
			'settings.saveError' => '設定の保存に失敗しました',
			'settings.licensesTitle' => 'ライセンス',
			_ => null,
		};
	}
}
