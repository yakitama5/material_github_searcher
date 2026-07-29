import 'package:flutter/material.dart';

/// アイコンの円形バッジ・ラベル・値を横に並べた1行の情報表示部品。
///
/// GitHubリポジトリの言語やスター数のような「アイコンで種別を示し、ラベルと値を
/// 対にして表示する」情報行の共通表現として使う。リポジトリ・検索など特定機能の
/// ドメイン知識は持たず、アイコン・色・文字列はすべて呼び出し側から受け取る。
/// 値の書式変換（数値の丸め表示など）も呼び出し側の責務とする。
class MetaInfoRow extends StatelessWidget {
  /// [icon]・[iconColor]・[label]・[value] から [MetaInfoRow] を生成する。
  const MetaInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    super.key,
  });

  /// 円形バッジの中に表示するアイコン。
  final IconData icon;

  /// 円形バッジの背景色。
  final Color iconColor;

  /// アイコンの右側に表示するラベル文字列。
  final String label;

  /// 行の右端に表示する値文字列。
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: iconColor,
          // iconColorは呼び出し側が任意に指定する背景色のため、ColorSchemeの色ではなく
          // 常に白を重ねてコントラストを確保する。
          // ignore: altive_lints_plugin/avoid_hardcoded_color
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
