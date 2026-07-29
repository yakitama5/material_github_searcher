import 'package:riverpod/misc.dart';

/// 本番環境向けのProvider override一式を生成する。
///
/// Repository実装が追加された後も、この関数へ結線を集約する。
List<Override> createProductionOverrides() => const <Override>[];

/// テスト・開発環境向けのProvider override一式を生成する。
///
/// Fake Repositoryが追加された後も、この関数へ結線を集約する。
List<Override> createMockOverrides() => const <Override>[];
