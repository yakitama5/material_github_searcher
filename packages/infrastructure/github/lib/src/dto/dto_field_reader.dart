/// GitHub APIのレスポンスJSONから`key`の値を`T`として取り出す。
///
/// `json`に`key`が存在しない、または値の型が`T`と一致しない場合は、
/// フィールド名を含む[FormatException]を投げる。呼び出し側（Repository実装）
/// はこれを捕捉してログ可能な`AppException`のサブタイプへ変換する。
T requireField<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! T) {
    throw FormatException(
      'GitHub search response is missing or has an invalid "$key" field '
      '(expected $T, got ${value.runtimeType})',
    );
  }
  return value;
}
