import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/strings.g.dart';
import '../ui_style_label.dart';

/// UI Style選択肢の[RadioListTile]のkeyを、[AppUiStyle]の値から解決する。
///
/// Widget Testから参照するため、実装とテストで同一のリテラルを再定義せず
/// 本関数を共有する。
Key settingsUiStyleOptionKey(AppUiStyle style) =>
    Key('settingsUiStyleOption_${style.name}');

/// UI Style（System/Android/iOS）選択画面。
///
/// [themeSettingsProvider]のみをSingle Source of Truthとしてwatchし、選択操作は
/// [ThemeSettingsNotifier.updateUiStyle]へ直接委譲する。同Notifierは楽観的
/// 更新後に永続化し、失敗時は直前値へrollbackして例外を投げる契約のため、
/// 本Widgetは[PresentationMixin]でその例外を受けてエラーSnackbarを表示する。
class SettingsUiStyleScreen extends ConsumerStatefulWidget {
  /// UI Style選択画面を生成する。
  const SettingsUiStyleScreen({super.key});

  @override
  ConsumerState<SettingsUiStyleScreen> createState() =>
      _SettingsUiStyleScreenState();
}

class _SettingsUiStyleScreenState extends ConsumerState<SettingsUiStyleScreen>
    with PresentationMixin {
  /// 呼出し中は選択肢を[RadioListTile.enabled]で無効化し、多重tapによる
  /// [ThemeSettingsNotifier]の呼出し直列化前提（呼出し元の責務）を守る。
  bool _saving = false;

  Future<void> _select(AppUiStyle uiStyle) async {
    setState(() => _saving = true);
    final i18n = context.i18n;
    try {
      await executePresentationAction(
        action: () =>
            ref.read(themeSettingsProvider.notifier).updateUiStyle(uiStyle),
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
        ref.watch(themeSettingsProvider).value?.uiStyle ?? AppUiStyle.system;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.settings.uiStyleTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: RadioGroup<AppUiStyle>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  unawaited(_select(value));
                }
              },
              child: ListView(
                children: [
                  for (final style in AppUiStyle.values)
                    RadioListTile<AppUiStyle>(
                      key: settingsUiStyleOptionKey(style),
                      title: Text(uiStyleLabel(style, i18n)),
                      value: style,
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
