import 'package:shared_preferences/shared_preferences.dart';

/// 本Package配下のRepository実装が共有する[SharedPreferencesAsync]を生成する。
///
/// [SharedPreferencesAsync]はkey単位で直接読み書きするだけで内部キャッシュを
/// 持たないため、生成コスト・状態を気にせずProviderが参照される都度
/// 生成してよい。呼び出し元（`dependency_override`）が`package:shared_preferences`
/// を直接importする必要をなくし、外部パッケージへの依存を本Packageへ閉じる。
SharedPreferencesAsync createSharedPreferencesAsync() =>
    SharedPreferencesAsync();
