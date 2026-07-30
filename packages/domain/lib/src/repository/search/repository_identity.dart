import 'package:meta/meta.dart';

/// GitHub Repositoryを一意に識別する値。
///
/// `owner/name` の組で識別するGitHub APIの規約に従い、両方を保持する。
@immutable
final class RepositoryIdentity {
  /// Repositoryの識別子を生成する。
  const RepositoryIdentity({required this.owner, required this.name});

  /// Repositoryを所有するuser・organizationのlogin名。
  final String owner;

  /// Repository名。
  final String name;

  /// `owner/name` 形式の完全名。
  String get fullName => '$owner/$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositoryIdentity &&
          runtimeType == other.runtimeType &&
          owner == other.owner &&
          name == other.name;

  @override
  int get hashCode => Object.hash(owner, name);
}
