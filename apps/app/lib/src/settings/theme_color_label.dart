import 'package:domain/domain.dart';

import '../../i18n/strings.g.dart';

/// [AppThemeColor]を表示ラベルへ変換する。
///
/// i18n変換はapp側の責務であるため、[AppThemeColor]自体には表示文言を持たせず、
/// 画面側で解決する。
String themeColorLabel(AppThemeColor color, Translations i18n) =>
    switch (color) {
      AppThemeColor.app => i18n.settings.themeColorApp,
      AppThemeColor.dynamic => i18n.settings.themeColorDynamic,
      AppThemeColor.blue => i18n.settings.themeColorBlue,
      AppThemeColor.purple => i18n.settings.themeColorPurple,
      AppThemeColor.pink => i18n.settings.themeColorPink,
      AppThemeColor.red => i18n.settings.themeColorRed,
      AppThemeColor.orange => i18n.settings.themeColorOrange,
      AppThemeColor.yellow => i18n.settings.themeColorYellow,
      AppThemeColor.green => i18n.settings.themeColorGreen,
    };
