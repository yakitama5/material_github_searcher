import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:fake_async/fake_async.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('CacheForExtension.cacheFor', () {
    const cacheDuration = Duration(minutes: 5);

    test('listener離脱後もtimeout前はProviderがdisposeされない', () {
      fakeAsync((async) {
        var disposeCount = 0;
        final provider = Provider.autoDispose<int>((ref) {
          ref
            ..cacheFor(cacheDuration)
            ..onDispose(() => disposeCount++);
          return 42;
        });
        final container = ProviderContainer();

        final sub = container.listen(provider, (_, _) {});
        expect(container.read(provider), 42);

        // 最後のlistenerが外れるとtimerが開始する（onCancel）。
        sub.close();
        async
          ..elapse(const Duration(minutes: 4))
          ..flushMicrotasks();

        expect(disposeCount, 0);

        container.dispose();
      });
    });

    test('timeout満了後にProviderがdispose可能になる', () {
      fakeAsync((async) {
        var disposeCount = 0;
        final provider = Provider.autoDispose<int>((ref) {
          ref
            ..cacheFor(cacheDuration)
            ..onDispose(() => disposeCount++);
          return 42;
        });
        final container = ProviderContainer();

        final sub = container.listen(provider, (_, _) {});
        container.read(provider);

        sub.close();
        // timer満了でkeepAliveが解除され、autoDisposeが走る。
        async
          ..elapse(cacheDuration)
          ..flushTimers();

        expect(disposeCount, 1);

        container.dispose();
      });
    });

    test('timeout前にlistenerが戻るとtimerが取り消され維持される', () {
      fakeAsync((async) {
        var disposeCount = 0;
        final provider = Provider.autoDispose<int>((ref) {
          ref
            ..cacheFor(cacheDuration)
            ..onDispose(() => disposeCount++);
          return 42;
        });
        final container = ProviderContainer();

        final sub1 = container.listen(provider, (_, _) {});
        container.read(provider);

        sub1.close();
        async.elapse(const Duration(minutes: 3));

        // 期限内にlistenerが戻る（onResume）とtimerが取り消される。
        final sub2 = container.listen(provider, (_, _) {});
        async
          ..elapse(const Duration(minutes: 10))
          ..flushTimers();

        expect(disposeCount, 0);

        sub2.close();
        container.dispose();
      });
    });
  });

  group('CancellationRefExtension.createCancellationController', () {
    test('生成直後のTokenはキャンセルされていない', () {
      late CancellationController controller;
      final provider = Provider.autoDispose<CancellationController>(
        (ref) => controller = ref.createCancellationController(),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);

      expect(controller.token.isCancelled, isFalse);
    });

    test('Providerのdisposeでcontrollerがcancelされる', () {
      late CancellationController controller;
      final provider = Provider.autoDispose<CancellationController>(
        (ref) => controller = ref.createCancellationController(),
      );
      final container = ProviderContainer()..read(provider);

      expect(controller.token.isCancelled, isFalse);

      container.dispose();

      expect(controller.token.isCancelled, isTrue);
    });

    test('Provider再計算時に古いcontrollerがcancelされ、新しいcontrollerは生存する', () {
      final controllers = <CancellationController>[];
      final provider = Provider.autoDispose<CancellationController>((ref) {
        final controller = ref.createCancellationController();
        controllers.add(controller);
        return controller;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      container
        ..read(provider)
        ..invalidate(provider)
        ..read(provider);

      expect(controllers, hasLength(2));
      // 再計算前の古いresourceは保持されず、cancelされる。
      expect(controllers[0].token.isCancelled, isTrue);
      expect(controllers[1].token.isCancelled, isFalse);
    });
  });
}
