import 'package:flutter/material.dart';

import '../../../../i18n/strings.g.dart';

/// keyboard submitとsearch buttonタップを同じ[onSubmit]へ統一する送信式SearchBar。
///
/// 入力中の文字列は[controller]がWidget側で保持し、Application Stateへは
/// [onSubmit]の呼び出し経由でのみ渡す。
class RepositorySearchBar extends StatelessWidget {
  /// [controller]の入力内容を[onSubmit]で送信するSearchBarを生成する。
  const RepositorySearchBar({
    required this.controller,
    required this.onSubmit,
    super.key,
  });

  /// 入力中の文字列を保持するController。
  final TextEditingController controller;

  /// keyboard submit・search buttonタップの両方から呼ばれる送信handler。
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
    return TextField(
      key: const Key('repositorySearchField'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: i18n.searchFieldHint,
        filled: true,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          key: const Key('repositorySearchSubmitButton'),
          icon: const Icon(Icons.search),
          tooltip: i18n.searchButtonTooltip,
          onPressed: () => onSubmit(controller.text),
        ),
      ),
      onSubmitted: onSubmit,
    );
  }
}
