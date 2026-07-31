/// アプリ全体で使うUI Style（Material/Cupertinoの見た目切り替え）の区分。
enum AppUiStyle {
  /// OSの種別に応じてMaterial・Cupertinoを自動選択する。
  system,

  /// OSに関わらずMaterialのUIで表示する。
  android,

  /// OSに関わらずCupertinoのUIで表示する。
  ios,
}
