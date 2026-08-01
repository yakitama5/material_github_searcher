import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../i18n/strings.g.dart';
import '../../router/app_routes.dart';
import '../ui_style_label.dart';

/// Settings一覧画面から各設定項目へ遷移する`ListTile`のkey。
///
/// Widget Testから参照するため、実装とテストで同一のリテラルを再定義せず
/// 本constを共有する。
const settingsUiStyleListTileKey = Key('settingsUiStyleListTile');

/// 設定一覧画面。
///
/// [themeSettingsProvider]のみをSingle Source of Truthとしてwatchし、
/// 画面固有のViewModelは持たない。
class SettingsScreen extends ConsumerWidget {
  /// 設定一覧画面を生成する。
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = context.i18n;
    final uiStyle =
        ref.watch(themeSettingsProvider).value?.uiStyle ?? AppUiStyle.system;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.settings.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: ListView(
              children: [
                ListTile(
                  key: settingsUiStyleListTileKey,
                  title: Text(i18n.settings.uiStyleTitle),
                  subtitle: Text(uiStyleLabel(uiStyle, i18n)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(settingsUiStyleRouteName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
