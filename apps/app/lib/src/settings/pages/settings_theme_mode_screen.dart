import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/strings.g.dart';
import '../theme_mode_label.dart';

/// Theme Mode選択肢の[RadioListTile]のkeyを、[AppThemeMode]の値から解決する。
///
/// Widget Testから参照するため、実装とテストで同一のリテラルを再定義せず
/// 本関数を共有する。
Key settingsThemeModeOptionKey(AppThemeMode mode) =>
    Key('settingsThemeModeOption_${mode.name}');

/// Theme Mode（System/Light/Dark）選択画面。
///
/// [themeSettingsProvider]のみをSingle Source of Truthとしてwatchし、選択操作は
/// [ThemeSettingsNotifier.updateThemeMode]へ直接委譲する。同Notifierは楽観的
/// 更新後に永続化し、失敗時は直前値へrollbackして例外を投げる契約のため、
/// 本Widgetは[PresentationMixin]でその例外を受けてエラーSnackbarを表示する。
class SettingsThemeModeScreen extends ConsumerStatefulWidget {
  /// Theme Mode選択画面を生成する。
  const SettingsThemeModeScreen({super.key});

  @override
  ConsumerState<SettingsThemeModeScreen> createState() =>
      _SettingsThemeModeScreenState();
}

class _SettingsThemeModeScreenState
    extends ConsumerState<SettingsThemeModeScreen>
    with PresentationMixin {
  /// 呼出し中は選択肢を[RadioListTile.enabled]で無効化し、多重tapによる
  /// [ThemeSettingsNotifier]の呼出し直列化前提（呼出し元の責務）を守る。
  bool _saving = false;

  Future<void> _select(AppThemeMode themeMode) async {
    setState(() => _saving = true);
    final i18n = context.i18n;
    try {
      await executePresentationAction(
        action: () =>
            ref.read(themeSettingsProvider.notifier).updateThemeMode(themeMode),
        errorMessageBuilder: (_) => i18n.settings.saveError,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n;
    final current =
        ref.watch(themeSettingsProvider).value?.themeMode ??
        AppThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.settings.themeModeTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: RadioGroup<AppThemeMode>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  unawaited(_select(value));
                }
              },
              child: ListView(
                children: [
                  for (final mode in AppThemeMode.values)
                    RadioListTile<AppThemeMode>(
                      key: settingsThemeModeOptionKey(mode),
                      title: Text(themeModeLabel(mode, i18n)),
                      value: mode,
                      enabled: !_saving,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
