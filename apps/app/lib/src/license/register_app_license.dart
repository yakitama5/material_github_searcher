import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `assets/LICENSE`の読込み結果をアプリ実行中を通じて使い回すcache。
///
/// [registerAppLicense]は`createApp`が呼ばれる度に実行されるが、同一assetへの
/// `rootBundle.loadString`を都度発行すると、Flutter Test環境では同一test file内
/// での2回目以降の呼出しが完了しない場合があるため、Futureそのものを再利用して
/// 呼出し回数を1回に抑える（`test/license/register_app_license_test.dart`で
/// 同一fileから複数回`registerAppLicense`/`createApp`を呼ぶ際に必要）。
Future<String>? _cachedLicense;

/// アプリ自身のMITライセンスを[LicenseRegistry]へ登録する。
///
/// リポジトリ直下の`LICENSE`を指す`assets/LICENSE`（シンボリックリンク）を
/// 読み込み、[appName]で識別可能なエントリとして追加する。ライセンス本文の
/// 実体はリポジトリ直下の`LICENSE`のみとし、複製しない。
void registerAppLicense(String appName) {
  LicenseRegistry.addLicense(() async* {
    final license = await (_cachedLicense ??= rootBundle.loadString(
      'assets/LICENSE',
    ));
    yield LicenseEntryWithLineBreaks([appName], license);
  });
}
