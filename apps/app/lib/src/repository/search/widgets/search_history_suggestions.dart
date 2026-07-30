import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../../i18n/strings.g.dart';

/// [SearchHistorySuggestions]全体を指すKey。Widget Testから参照する。
const repositorySearchHistorySuggestionsKey = Key(
  'repositorySearchHistorySuggestions',
);

/// 「履歴をすべて削除」ボタンを指すKey。Widget Testから参照する。
const repositorySearchHistoryClearAllButtonKey = Key(
  'repositorySearchHistoryClearAllButton',
);

/// 全削除確認Dialogの削除ボタンを指すKey。Widget Testから参照する。
const repositorySearchHistoryClearAllConfirmKey = Key(
  'repositorySearchHistoryClearAllConfirm',
);

/// 全削除確認Dialogのキャンセルボタンを指すKey。Widget Testから参照する。
const repositorySearchHistoryClearAllCancelKey = Key(
  'repositorySearchHistoryClearAllCancel',
);

/// [keyword]に対応する候補行を指すKeyを生成する。Widget Testから参照する。
Key repositorySearchHistorySuggestionItemKey(String keyword) =>
    Key('repositorySearchHistorySuggestionItem-$keyword');

/// SearchBarフォーカス時に表示する検索履歴の候補一覧。
///
/// [entries]は呼び出し元の画面が絞り込み済みの一覧を渡す。本Widgetは表示と
/// 「すべて削除」の確認Dialogだけを担い、履歴の
/// 絞り込みルール自体は持たない。
class SearchHistorySuggestions extends StatelessWidget {
  /// [entries]を候補一覧として表示するサジェストを生成する。
  const SearchHistorySuggestions({
    required this.entries,
    required this.onSelect,
    required this.onClearAllConfirmed,
    super.key,
  });

  /// 表示する候補一覧（呼び出し元で絞り込み済み）。
  final List<SearchHistoryEntry> entries;

  /// 候補選択時に選択されたkeywordを渡すcallback。
  final ValueChanged<String> onSelect;

  /// 全削除確認Dialogで削除が確定された時に呼ばれるcallback。
  final VoidCallback onClearAllConfirmed;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
    return Card(
      key: repositorySearchHistorySuggestionsKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            title: Text(
              i18n.historySuggestionsLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            trailing: Tooltip(
              message: i18n.historyClearAllTooltip,
              child: TextButton(
                key: repositorySearchHistoryClearAllButtonKey,
                onPressed: () => _confirmClearAll(context),
                child: Text(i18n.historyClearAllLabel),
              ),
            ),
          ),
          for (final entry in entries)
            ListTile(
              key: repositorySearchHistorySuggestionItemKey(entry.keyword),
              leading: const Icon(Icons.history),
              title: Text(entry.keyword),
              onTap: () => onSelect(entry.keyword),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final i18n = context.i18n.repositorySearch;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.historyClearAllDialogTitle),
        content: Text(i18n.historyClearAllDialogMessage),
        actions: [
          TextButton(
            key: repositorySearchHistoryClearAllCancelKey,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(i18n.historyClearAllDialogCancel),
          ),
          TextButton(
            key: repositorySearchHistoryClearAllConfirmKey,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(i18n.historyClearAllDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      onClearAllConfirmed();
    }
  }
}
