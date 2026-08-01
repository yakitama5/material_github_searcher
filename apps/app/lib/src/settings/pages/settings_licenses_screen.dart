import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_title_provider.dart';

/// ライセンス一覧画面。
///
/// Flutter標準の[LicensePage]をそのまま表示し、AppBar・戻る・長文scroll等の
/// 標準挙動を維持する。独自のライセンス一覧やWebViewは実装しない。
class SettingsLicensesScreen extends ConsumerWidget {
  /// ライセンス一覧画面を生成する。
  const SettingsLicensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LicensePage(applicationName: ref.watch(appTitleProvider));
  }
}
