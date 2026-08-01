import 'package:domain/domain.dart';

import '../../i18n/strings.g.dart';

/// [AppUiStyle]を表示ラベルへ変換する。
///
/// i18n変換はapp側の責務であるため、`domain`の[AppUiStyle]自体には
/// 表示文言を持たせず、本Widgetで解決する。
String uiStyleLabel(AppUiStyle style, Translations i18n) => switch (style) {
  AppUiStyle.system => i18n.settings.uiStyleSystem,
  AppUiStyle.android => i18n.settings.uiStyleAndroid,
  AppUiStyle.ios => i18n.settings.uiStyleIos,
};
