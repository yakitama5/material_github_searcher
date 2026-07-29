import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

final _messageProvider = Provider<String>((ref) => 'production');

void main() {
  test('ProviderContainerを生成して破棄できる', () {
    final container = ProviderContainer();

    expect(container.read(_messageProvider), 'production');
    expect(container.dispose, returnsNormally);
  });

  test('手書きProviderの値をoverrideできる', () {
    final container = ProviderContainer(
      overrides: [_messageProvider.overrideWithValue('mock')],
    );
    addTearDown(container.dispose);

    expect(container.read(_messageProvider), 'mock');
  });
}
