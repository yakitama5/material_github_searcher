import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';

/// 初回loading中に表示する固定件数のRepository一覧行Skeleton。
///
/// `SkeletonScope`で1つのアニメーションを共有し、行数を実際の取得件数に
/// 依存させず固定値にすることで、応答前から一覧のレイアウトを示す。
class RepositoryListSkeleton extends StatelessWidget {
  /// Repository一覧行Skeletonを生成する。
  const RepositoryListSkeleton({super.key});

  static const _rowCount = 6;

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: Column(
        children: List.generate(
          _rowCount,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _RepositoryRowSkeleton(),
          ),
        ),
      ),
    );
  }
}

/// 追加ページ取得中に一覧末尾へ表示する1行分のSkeleton。
///
/// [RepositoryListSkeleton]と異なりリスト全体を対象にしないため、単独で
/// [SkeletonScope]を持つ。
class RepositoryListItemSkeleton extends StatelessWidget {
  /// 末尾用の1行Skeletonを生成する。
  const RepositoryListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonScope(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _RepositoryRowSkeleton(),
      ),
    );
  }
}

class _RepositoryRowSkeleton extends StatelessWidget {
  const _RepositoryRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonCircle(diameter: 40),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonText(width: 180),
              SizedBox(height: 8),
              SkeletonText(width: 120, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
