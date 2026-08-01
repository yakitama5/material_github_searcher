///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsEn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsEn _root = this; // ignore: unused_field

	@override 
	TranslationsEn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$repositoryDetail$en repositoryDetail = _Translations$repositoryDetail$en._(_root);
	@override late final _Translations$repositorySearch$en repositorySearch = _Translations$repositorySearch$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
}

// Path: common
class _Translations$common$en extends Translations$common$ja {
	_Translations$common$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get pushCountLabel => 'You have pushed the button this many times';
	@override String get incrementTooltip => 'Increment';
	@override late final _Translations$common$navigation$en navigation = _Translations$common$navigation$en._(_root);
}

// Path: repositoryDetail
class _Translations$repositoryDetail$en extends Translations$repositoryDetail$ja {
	_Translations$repositoryDetail$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get languageLabel => 'Language';
	@override String get languageUnset => 'Not set';
	@override String get starsLabel => 'Stars';
	@override String starsValue({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}';
	@override String get forksLabel => 'Forks';
	@override String forksValue({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}';
	@override String get issuesLabel => 'Issues';
	@override String issuesValue({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}';
	@override String get watchersLabel => 'Watchers';
	@override String watchersValue({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}';
	@override String get watcherError => 'Failed to load watcher count';
	@override String get retry => 'Retry';
	@override String get retryTooltip => 'Retry fetching the watcher count';
}

// Path: repositorySearch
class _Translations$repositorySearch$en extends Translations$repositorySearch$ja {
	_Translations$repositorySearch$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get searchFieldLabel => 'Search repositories';
	@override String get searchFieldHint => 'Enter a repository name or keyword';
	@override String get searchButtonTooltip => 'Search';
	@override String get guidance => 'Enter a keyword, then submit from the keyboard or the search button.';
	@override String get emptyTitle => 'No repositories matched your search.';
	@override String get emptyHint => 'Try a different keyword and search again.';
	@override String get errorGeneric => 'Something went wrong. Please try again later.';
	@override String get errorRateLimited => 'GitHub API rate limit reached. Please try again later.';
	@override String get retry => 'Retry';
	@override String get refreshing => 'Refreshing';
	@override String get languageUnset => 'Not set';
	@override String get languageLabel => 'Language';
	@override String get starsLabel => 'Stars';
	@override String get historySuggestionsLabel => 'Search history';
	@override String get historyClearAllLabel => 'Clear all';
	@override String get historyClearAllTooltip => 'Clear all search history';
	@override String get historyClearAllDialogTitle => 'Delete search history?';
	@override String get historyClearAllDialogMessage => 'This removes all saved search history. This action cannot be undone.';
	@override String get historyClearAllDialogConfirm => 'Delete';
	@override String get historyClearAllDialogCancel => 'Cancel';
}

// Path: settings
class _Translations$settings$en extends Translations$settings$ja {
	_Translations$settings$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings';
	@override String get uiStyleTitle => 'UI Style';
	@override String get uiStyleSystem => 'System';
	@override String get uiStyleAndroid => 'Android';
	@override String get uiStyleIos => 'iOS';
	@override String get themeModeTitle => 'Theme Mode';
	@override String get themeModeSystem => 'System';
	@override String get themeModeLight => 'Light';
	@override String get themeModeDark => 'Dark';
	@override String get saveError => 'Failed to save the setting';
	@override String get licensesTitle => 'Licenses';
}

// Path: common.navigation
class _Translations$common$navigation$en extends Translations$common$navigation$ja {
	_Translations$common$navigation$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get search => 'Search';
	@override String get settings => 'Settings';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.pushCountLabel' => 'You have pushed the button this many times',
			'common.incrementTooltip' => 'Increment',
			'common.navigation.search' => 'Search',
			'common.navigation.settings' => 'Settings',
			'repositoryDetail.languageLabel' => 'Language',
			'repositoryDetail.languageUnset' => 'Not set',
			'repositoryDetail.starsLabel' => 'Stars',
			'repositoryDetail.starsValue' => ({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}',
			'repositoryDetail.forksLabel' => 'Forks',
			'repositoryDetail.forksValue' => ({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}',
			'repositoryDetail.issuesLabel' => 'Issues',
			'repositoryDetail.issuesValue' => ({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}',
			'repositoryDetail.watchersLabel' => 'Watchers',
			'repositoryDetail.watchersValue' => ({required num count}) => '${NumberFormat.decimalPattern('en').format(count)}',
			'repositoryDetail.watcherError' => 'Failed to load watcher count',
			'repositoryDetail.retry' => 'Retry',
			'repositoryDetail.retryTooltip' => 'Retry fetching the watcher count',
			'repositorySearch.searchFieldLabel' => 'Search repositories',
			'repositorySearch.searchFieldHint' => 'Enter a repository name or keyword',
			'repositorySearch.searchButtonTooltip' => 'Search',
			'repositorySearch.guidance' => 'Enter a keyword, then submit from the keyboard or the search button.',
			'repositorySearch.emptyTitle' => 'No repositories matched your search.',
			'repositorySearch.emptyHint' => 'Try a different keyword and search again.',
			'repositorySearch.errorGeneric' => 'Something went wrong. Please try again later.',
			'repositorySearch.errorRateLimited' => 'GitHub API rate limit reached. Please try again later.',
			'repositorySearch.retry' => 'Retry',
			'repositorySearch.refreshing' => 'Refreshing',
			'repositorySearch.languageUnset' => 'Not set',
			'repositorySearch.languageLabel' => 'Language',
			'repositorySearch.starsLabel' => 'Stars',
			'repositorySearch.historySuggestionsLabel' => 'Search history',
			'repositorySearch.historyClearAllLabel' => 'Clear all',
			'repositorySearch.historyClearAllTooltip' => 'Clear all search history',
			'repositorySearch.historyClearAllDialogTitle' => 'Delete search history?',
			'repositorySearch.historyClearAllDialogMessage' => 'This removes all saved search history. This action cannot be undone.',
			'repositorySearch.historyClearAllDialogConfirm' => 'Delete',
			'repositorySearch.historyClearAllDialogCancel' => 'Cancel',
			'settings.title' => 'Settings',
			'settings.uiStyleTitle' => 'UI Style',
			'settings.uiStyleSystem' => 'System',
			'settings.uiStyleAndroid' => 'Android',
			'settings.uiStyleIos' => 'iOS',
			'settings.themeModeTitle' => 'Theme Mode',
			'settings.themeModeSystem' => 'System',
			'settings.themeModeLight' => 'Light',
			'settings.themeModeDark' => 'Dark',
			'settings.saveError' => 'Failed to save the setting',
			'settings.licensesTitle' => 'Licenses',
			_ => null,
		};
	}
}
