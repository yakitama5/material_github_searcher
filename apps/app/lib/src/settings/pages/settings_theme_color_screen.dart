import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/strings.g.dart';
import '../../theme/dynamic_color_scope.dart';
import '../theme_color_label.dart';
import '../widgets/theme_color_preview.dart';

/// Theme Color選択肢をIssueで定めた順序で固定する。
const settingsThemeColorOptions = [
  AppThemeColor.app,
  AppThemeColor.dynamic,
  AppThemeColor.blue,
  AppThemeColor.purple,
  AppThemeColor.pink,
  AppThemeColor.red,
  AppThemeColor.orange,
  AppThemeColor.yellow,
  AppThemeColor.green,
];

/// Theme Color選択肢の[RadioListTile]のkeyを、[AppThemeColor]の値から解決する。
///
/// Widget Testから参照するため、実装とテストで同じリテラルを再定義しない。
Key settingsThemeColorOptionKey(AppThemeColor color) =>
    Key('settingsThemeColorOption_${color.name}');

/// Theme Colorのpreviewのkeyを解決する。
Key settingsThemeColorPreviewKey(AppThemeColor color) =>
    Key('settingsThemeColorPreview_${color.name}');

/// Theme Color（App/Dynamic/固定色）選択画面。
class SettingsThemeColorScreen extends ConsumerStatefulWidget {
  /// Theme Color選択画面を生成する。
  const SettingsThemeColorScreen({super.key});

  @override
  ConsumerState<SettingsThemeColorScreen> createState() =>
      _SettingsThemeColorScreenState();
}

class _SettingsThemeColorScreenState
    extends ConsumerState<SettingsThemeColorScreen>
    with PresentationMixin {
  /// 呼出し中は選択肢を無効化し、Notifierの直列化前提を守る。
  bool _saving = false;

  Future<void> _select(AppThemeColor themeColor) async {
    setState(() => _saving = true);
    final i18n = context.i18n;
    try {
      await executePresentationAction(
        action: () => ref
            .read(themeSettingsProvider.notifier)
            .updateThemeColor(themeColor),
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
    final themeSettingsState = ref.watch(themeSettingsProvider);
    final current = themeSettingsState.value?.themeColor ?? AppThemeColor.app;
    final dynamicColorScope = DynamicColorScope.maybeOf(context);
    final dynamicAvailable =
        dynamicColorScope?.isAvailableFor(
          Theme.of(context).brightness,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.settings.themeColorTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: RadioGroup<AppThemeColor>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  unawaited(_select(value));
                }
              },
              child: ListView(
                children: [
                  if (!dynamicAvailable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(i18n.settings.themeColorDynamicFallback),
                    ),
                  for (final color in settingsThemeColorOptions)
                    RadioListTile<AppThemeColor>(
                      key: settingsThemeColorOptionKey(color),
                      title: Text(themeColorLabel(color, i18n)),
                      secondary: ThemeColorPreview(
                        key: settingsThemeColorPreviewKey(color),
                        themeColor: color,
                      ),
                      value: color,
                      enabled:
                          !_saving &&
                          themeSettingsState.hasValue &&
                          !themeSettingsState.isLoading &&
                          !themeSettingsState.hasError,
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
