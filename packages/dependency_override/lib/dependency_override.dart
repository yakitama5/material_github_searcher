/// Composition bindings between application contracts and adapters.
library;

// Patrolなどの外側のテストコードが、apps/appから直接
// infrastructure_mockへ依存せずに決定的なfixtureを設定できるよう公開する。
export 'package:infrastructure_mock/infrastructure_mock.dart';
export 'src/override_sets.dart';
