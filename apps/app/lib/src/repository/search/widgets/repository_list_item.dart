import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../../i18n/strings.g.dart';

/// data時の1件分のRepository検索結果を表示する行。
///
/// 名前・owner icon・language・Starを最低限表示する。owner iconの読み込み
/// 失敗時はfallback avatarへ切り替え、languageが`null`の場合はローカライズ
/// した「未設定」を表示する。detail遷移は後続Issueが実装するため、[onTap]は
/// 呼び出し口を用意するのみで本Issueでは渡さない。
class RepositoryListItem extends StatelessWidget {
  /// [summary]の1件を表示する行を生成する。
  const RepositoryListItem({required this.summary, this.onTap, super.key});

  /// 表示するRepository検索結果。
  final RepositorySummary summary;

  /// 行タップ時のcallback。detail遷移が未実装のため`null`のままでよい。
  final ValueChanged<RepositoryIdentity>? onTap;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
    final colorScheme = Theme.of(context).colorScheme;
    final fullName = summary.identity.fullName;
    final languageLabel = summary.language ?? i18n.languageUnset;
    final starsValue = '${summary.stargazersCount}';
    final onTap = this.onTap;

    return Semantics(
      label:
          '$fullName, ${i18n.languageLabel}: $languageLabel, '
          '${i18n.starsLabel}: $starsValue',
      button: onTap != null,
      onTap: onTap == null ? null : () => onTap(summary.identity),
      child: ExcludeSemantics(
        child: ListTile(
          onTap: onTap == null ? null : () => onTap(summary.identity),
          leading: _OwnerAvatar(imageUrl: summary.ownerAvatarUrl),
          title: Text(fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              Expanded(
                child: MetaInfoRow(
                  icon: Icons.code,
                  iconColor: colorScheme.secondary,
                  label: i18n.languageLabel,
                  value: languageLabel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetaInfoRow(
                  icon: Icons.star,
                  iconColor: colorScheme.tertiary,
                  label: i18n.starsLabel,
                  value: starsValue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({required this.imageUrl});

  final String imageUrl;

  static const _diameter = 40.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: _diameter,
        height: _diameter,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: SizedBox(
            width: _diameter,
            height: _diameter,
            child: Icon(
              Icons.person,
              size: 24,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
