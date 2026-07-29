import 'dart:async';

import 'package:application/application.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// テスト用に [RunUsecaseMixin] を利用するUseCase。
class _TestUsecase with RunUsecaseMixin {
  Future<T> call<T>(
    Ref ref, {
    required Future<T> Function() action,
    bool disableLoading = false,
  }) => execute(ref, action: action, disableLoading: disableLoading);
}

/// UseCaseへ渡す [Ref] を取得するためのテスト用Provider。
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUp(() {
    container = ProviderContainer();
    ref = container.read(_refProvider);
  });

  tearDown(() {
    container.dispose();
  });

  int loading() => container.read(appLoadingProvider);

  test('初期状態のローディングカウントは0である', () {
    expect(loading(), 0);
  });

  test('1処理の成功でカウントが+1され、完了後に0へ戻る', () async {
    final completer = Completer<int>();
    final usecase = _TestUsecase();

    final future = usecase.call(ref, action: () => completer.future);
    expect(loading(), 1);

    completer.complete(42);
    expect(await future, 42);
    expect(loading(), 0);
  });

  test('1処理の失敗でも例外を伝播しつつカウントが0へ戻る', () async {
    final completer = Completer<int>();
    final usecase = _TestUsecase();

    final future = usecase.call(ref, action: () => completer.future);
    expect(loading(), 1);

    completer.completeError(Exception('failure'));
    await expectLater(future, throwsException);
    expect(loading(), 0);
  });

  test('2処理を並行実行し、完了順が異なってもカウントを正しく保持する', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    final usecase = _TestUsecase();

    final firstFuture = usecase.call(ref, action: () => first.future);
    final secondFuture = usecase.call(ref, action: () => second.future);
    expect(loading(), 2);

    // 後発の処理を先に完了させる。残処理があるためカウントは1のまま。
    second.complete();
    await secondFuture;
    expect(loading(), 1);

    first.complete();
    await firstFuture;
    expect(loading(), 0);
  });

  test('disableLoading:true ではローディングカウントを変更しない', () async {
    final completer = Completer<int>();
    final usecase = _TestUsecase();

    final future = usecase.call(
      ref,
      action: () => completer.future,
      disableLoading: true,
    );
    expect(loading(), 0);

    completer.complete(7);
    expect(await future, 7);
    expect(loading(), 0);
  });
}
