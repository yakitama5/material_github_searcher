import 'package:domain/domain.dart';

import '../../i18n/strings.g.dart';

/// [AppThemeMode]を表示ラベルへ変換する。
///
/// i18n変換はapp側の責務であるため、`domain`の[AppThemeMode]自体には
/// 表示文言を持たせず、本Widgetで解決する。
String themeModeLabel(AppThemeMode mode, Translations i18n) => switch (mode) {
  AppThemeMode.system => i18n.settings.themeModeSystem,
  AppThemeMode.light => i18n.settings.themeModeLight,
  AppThemeMode.dark => i18n.settings.themeModeDark,
};
