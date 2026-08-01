import 'dart:async';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// [SearchHistoryRepository]のテスト用Fake。
final class _FakeSearchHistoryRepository implements SearchHistoryRepository {
  SearchHistory? loadResult;
  AppException? loadError;
  AppException? saveError;

  /// 非空の場合、`save`呼び出しごとに先頭から1つずつ消費してそのエラーを
  /// 適用する（`null`なら成功）。[saveGate]によって完了順序が呼び出し順序と
  /// 入れ替わっても、どの呼び出しにどのエラーを対応させたいかをテスト側で
  /// 制御できるよう、消費は`save`呼び出し開始時点（gate待機より前）で行う。
  final List<AppException?> saveErrorQueue = [];

  /// 非`null`の場合、`load`は完了前にこの[Completer]を待つ。
  Completer<void>? loadGate;

  /// 非`null`の場合、`save`は完了前にこの[Completer]を待つ。
  ///
  /// 呼び出し順序が完了順序と入れ替わる状況（先発の`save`が後発より遅れて
  /// 完了する状況）を再現するために使う。
  Completer<void>? saveGate;

  int loadCallCount = 0;
  final List<SearchHistory> savedHistories = [];

  @override
  Future<SearchHistory> load() async {
    loadCallCount++;
    final gate = loadGate;
    if (gate != null) {
      await gate.future;
    }
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return loadResult ?? SearchHistory();
  }

  @override
  Future<void> save(SearchHistory history) async {
    final error = saveErrorQueue.isNotEmpty
        ? saveErrorQueue.removeAt(0)
        : saveError;
    final gate = saveGate;
    if (gate != null) {
      await gate.future;
    }
    if (error != null) {
      throw error;
    }
    savedHistories.add(history);
  }
}

void main() {
  late _FakeSearchHistoryRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakeSearchHistoryRepository();
    container = ProviderContainer(
      overrides: [searchHistoryRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  SearchHistoryController controller() =>
      container.read(searchHistoryControllerProvider.notifier);

  SearchHistoryState state() => container.read(searchHistoryControllerProvider);

  group('初期状態', () {
    test('loadingかつ空の履歴である', () {
      final current = state();
      expect(current.status, SearchHistoryStatus.loading);
      expect(current.history.entries, isEmpty);
      expect(fake.loadCallCount, 0);
    });
  });

  group('load', () {
    test('成功で永続化済み履歴をreadyへ反映する', () async {
      fake.loadResult = SearchHistory().recordSubmittedKeyword('flutter');

      await controller().load();

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history, fake.loadResult);
    });

    test('失敗時はメモリ上の履歴（空）を維持しpersistenceErrorへ遷移する', () async {
      const error = SearchHistoryPersistenceException(message: 'load failed');
      fake.loadError = error;

      await controller().load();

      final current = state();
      expect(current.status, SearchHistoryStatus.persistenceError);
      expect(current.error, error);
      expect(current.history.entries, isEmpty);
    });

    test('先発loadの遅延完了は後発loadが確定させた最新履歴を上書きしない', () async {
      final gateA = Completer<void>();
      fake
        ..loadGate = gateA
        ..loadResult = SearchHistory().recordSubmittedKeyword('A');

      // 先発loadはgateAで止める。
      final loadFuture1 = controller().load();
      expect(state().status, SearchHistoryStatus.loading);

      // 後発loadは即座に異なる結果(B)で完了し、最新のreadyへ進む。
      fake
        ..loadGate = null
        ..loadResult = SearchHistory().recordSubmittedKeyword('B');
      await controller().load();
      expect(state().status, SearchHistoryStatus.ready);
      expect(state().history.entries, [SearchHistoryEntry('B')]);

      // 先発loadを異なる結果(A)で完了させる。
      fake.loadResult = SearchHistory().recordSubmittedKeyword('A');
      gateA.complete();
      await loadFuture1;

      // 先発の遅延完了によって、後発が確定させた最新履歴(B)が
      // 古いスナップショット(A)へ巻き戻らない。
      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [SearchHistoryEntry('B')]);
    });
  });

  group('recordSubmittedKeyword', () {
    test('trimして先頭に記録し永続化する', () async {
      await controller().load();

      await controller().recordSubmittedKeyword('  flutter  ');

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [SearchHistoryEntry('flutter')]);
      expect(fake.savedHistories.single, current.history);
    });

    test('空文字は無視し履歴・永続化ともに変更しない', () async {
      await controller().recordSubmittedKeyword('   ');

      expect(state().status, SearchHistoryStatus.loading);
      expect(state().history.entries, isEmpty);
      expect(fake.savedHistories, isEmpty);
      // 空文字はloadを試行する前に無視されるべきno-opであることを確認する。
      expect(fake.loadCallCount, 0);
    });

    test('検索APIの成否に関わらず無条件で記録する', () async {
      // recordSubmittedKeywordは検索結果を引数に取らないため、
      // API成功・失敗・0件のいずれの文脈からでも同じ挙動で記録できる。
      await controller().load();

      await controller().recordSubmittedKeyword('no-results-keyword');

      expect(state().history.entries, [
        SearchHistoryEntry('no-results-keyword'),
      ]);
    });

    test('永続化失敗時も楽観更新した履歴は維持しpersistenceErrorへ遷移する', () async {
      await controller().load();
      const error = SearchHistoryPersistenceException(message: 'save failed');
      fake.saveError = error;

      await controller().recordSubmittedKeyword('flutter');

      final current = state();
      expect(current.status, SearchHistoryStatus.persistenceError);
      expect(current.error, error);
      expect(current.history.entries, [SearchHistoryEntry('flutter')]);
    });

    test('重複keywordは先頭へ移動して永続化する', () async {
      await controller().load();

      await controller().recordSubmittedKeyword('flutter');
      await controller().recordSubmittedKeyword('dart');
      await controller().recordSubmittedKeyword('flutter');

      expect(state().history.entries, [
        SearchHistoryEntry('flutter'),
        SearchHistoryEntry('dart'),
      ]);
      expect(fake.savedHistories, hasLength(3));
    });

    test('先発呼び出しの遅延失敗は、直列化された後発のsaveまで巻き戻さない', () async {
      await controller().load();
      final gate = Completer<void>();
      const error = SearchHistoryPersistenceException(message: 'save failed');
      fake
        ..saveGate = gate
        // 先発(flutter)のsaveは失敗、後発(dart)のsaveは成功させる。直列化
        // により実際の呼び出し順は開始順（flutter→dart）のまま保たれるため、
        // 呼び出し順でのエラー割り当てになる。
        ..saveErrorQueue.addAll([error, null]);

      // 先発(flutter)のsaveはgateで止め、後発(dart)より遅く完了させる。
      final future1 = controller().recordSubmittedKeyword('flutter');
      expect(state().history.entries, [SearchHistoryEntry('flutter')]);

      // 後発(dart)はgateの影響を受けず、最新のreadyへ即座に進む（実際の
      // save呼び出しは直列化キューに乗り、先発のsave完了後に実行される）。
      fake.saveGate = null;
      final future2 = controller().recordSubmittedKeyword('dart');
      expect(state().status, SearchHistoryStatus.ready);
      expect(state().history.entries, [
        SearchHistoryEntry('dart'),
        SearchHistoryEntry('flutter'),
      ]);

      // 先発のsaveを失敗させて完了させる。
      gate.complete();
      await Future.wait([future1, future2]);

      // 先発の遅延失敗によって、後発が確定させた最新履歴が古いスナップ
      // ショット（dartを含まないflutterのみの履歴）へ巻き戻らない。後発
      // (dart)自体のsaveは先発の失敗の影響を受けず、diskへ正しく反映される。
      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [
        SearchHistoryEntry('dart'),
        SearchHistoryEntry('flutter'),
      ]);
      expect(fake.savedHistories.last.entries, current.history.entries);
    });

    test(
      '先発呼び出しのsave完了が後発より遅れても、diskには後発が確定させた'
      '最新履歴が残る（Issue #112）',
      () async {
        await controller().load();
        final gate = Completer<void>();
        fake.saveGate = gate;

        // 先発(flutter)のsaveはgateで止め、後発(dart)より遅く完了させる。
        final future1 = controller().recordSubmittedKeyword('flutter');
        expect(state().history.entries, [SearchHistoryEntry('flutter')]);

        // 後発(dart)はgateの影響を受けず、最新のreadyへ進む。
        fake.saveGate = null;
        final future2 = controller().recordSubmittedKeyword('dart');
        expect(state().status, SearchHistoryStatus.ready);
        expect(state().history.entries, [
          SearchHistoryEntry('dart'),
          SearchHistoryEntry('flutter'),
        ]);

        // 先発のsaveを（失敗ではなく）成功で完了させる。
        gate.complete();
        await Future.wait([future1, future2]);

        final current = state();
        expect(current.status, SearchHistoryStatus.ready);
        expect(current.history.entries, [
          SearchHistoryEntry('dart'),
          SearchHistoryEntry('flutter'),
        ]);
        // save()完了の順序が開始順序と入れ替わっても、diskに最終的に残る
        // べきは常に後発(dart)が確定させた最新履歴であり、先発
        // (flutterのみ)の遅延完了で上書きされてはならない。
        expect(fake.savedHistories.last.entries, current.history.entries);
        // 直列化により、save自体は開始順（flutter→dart）で2回実行される。
        // 先発(flutter)は既に実行中でキャンセルできないため、古い内容の
        // ままdiskへ一度反映されるが、直後の後発(dart)のsaveで正しい内容に
        // 修正される。件数・順序まで固定することで、coalesce条件が変わり
        // 「後発のsaveが先発を追い越して実行される」退行が起きても検知
        // できるようにする（coalesceが対象とするのは、ループが追いつく前に
        // まだ実行されていない中間的な呼び出しであり、既に実行中の呼び出し
        // を打ち切るものではない点に注意）。
        expect(fake.savedHistories, hasLength(2));
        expect(fake.savedHistories.first.entries, [
          SearchHistoryEntry('flutter'),
        ]);
      },
    );
  });

  group('recordSubmittedKeyword: load未完了・失敗時の競合', () {
    test('loadの完了前に記録すると、loadの結果を基点に記録する', () async {
      final gate = Completer<void>();
      fake
        ..loadResult = SearchHistory().recordSubmittedKeyword('dart')
        ..loadGate = gate;

      // 起動時のload()が完了する前に、ユーザーがkeywordを送信したとする。
      final loadFuture = controller().load();
      final recordFuture = controller().recordSubmittedKeyword('flutter');

      // load完了を待つ間も、楽観更新した内容は同期的に見える。
      expect(state().status, SearchHistoryStatus.ready);
      expect(state().history.entries, [SearchHistoryEntry('flutter')]);

      // load()を完了させる。永続化済み履歴(dart)を基点に、記録した
      // keyword(flutter)を積み直した結果になる（どちらも失わない）。
      gate.complete();
      await loadFuture;
      await recordFuture;

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [
        SearchHistoryEntry('flutter'),
        SearchHistoryEntry('dart'),
      ]);
      expect(fake.savedHistories.single.entries, current.history.entries);
    });

    test('loadの完了前に複数回記録すると、全てloadの結果の上に積み重ねられる', () async {
      final gate = Completer<void>();
      fake
        ..loadResult = SearchHistory().recordSubmittedKeyword('old')
        ..loadGate = gate;

      final loadFuture = controller().load();
      final future1 = controller().recordSubmittedKeyword('flutter');
      final future2 = controller().recordSubmittedKeyword('dart');

      gate.complete();
      await loadFuture;
      await Future.wait([future1, future2]);

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [
        SearchHistoryEntry('dart'),
        SearchHistoryEntry('flutter'),
        SearchHistoryEntry('old'),
      ]);
      // 最新の呼び出しが確定するまで、途中の再構築は永続化しない。
      expect(fake.savedHistories, hasLength(1));
    });

    test('loadが失敗した状態で記録すると、再試行にも失敗した場合は永続化せずメモリ上のみ楽観更新する', () async {
      const error = SearchHistoryPersistenceException(message: 'load failed');
      fake.loadError = error;
      await controller().load();
      expect(state().status, SearchHistoryStatus.persistenceError);

      await controller().recordSubmittedKeyword('flutter');

      final current = state();
      // 実体を確認できないまま上書きするとデータ損失になるため、
      // メモリ上の楽観更新のみ維持し、save()は呼ばない。
      expect(current.status, SearchHistoryStatus.persistenceError);
      expect(current.error, error);
      expect(current.history.entries, [SearchHistoryEntry('flutter')]);
      expect(fake.savedHistories, isEmpty);
    });

    test('loadが失敗した状態で記録すると、再試行に成功した場合はその結果を基点に記録・永続化する', () async {
      const error = SearchHistoryPersistenceException(message: 'load failed');
      fake.loadError = error;
      await controller().load();
      expect(state().status, SearchHistoryStatus.persistenceError);

      fake
        ..loadError = null
        ..loadResult = SearchHistory().recordSubmittedKeyword('dart');
      await controller().recordSubmittedKeyword('flutter');

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [
        SearchHistoryEntry('flutter'),
        SearchHistoryEntry('dart'),
      ]);
      expect(fake.savedHistories.single.entries, current.history.entries);
    });

    test('staleと判定され破棄された読込は、実体確認済みとして扱わない', () async {
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      fake
        ..loadResult = SearchHistory().recordSubmittedKeyword('dart')
        ..loadGate = gateA;

      // 起動時load(世代1)を発行する。まだgateAで止まっている。
      final loadFuture = controller().load();

      // 以降の内部読込はgateBで止める。
      fake.loadGate = gateB;
      final futureA = controller().recordSubmittedKeyword('flutter');

      // 起動時loadをgateAの完了で進める。この時点で世代は既にrecord(A)に
      // よって進んでいるため、load自身はstaleとして結果(dart)を捨てる。
      gateA.complete();
      await loadFuture;

      // loadのstaleな読込によって「実体確認済み」フラグが誤って立って
      // いれば、この記録はdisk再読込を経ずメモリだけでsave()してしまい、
      // まだ確認していない実体(dart)を永久に失う。
      final futureB = controller().recordSubmittedKeyword('python');

      gateB.complete();
      await Future.wait([futureA, futureB]);

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [
        SearchHistoryEntry('python'),
        SearchHistoryEntry('flutter'),
        SearchHistoryEntry('dart'),
      ]);
      expect(fake.savedHistories.last.entries, current.history.entries);
    });
  });

  group('clearAll', () {
    test('履歴を空にして永続化する', () async {
      await controller().recordSubmittedKeyword('flutter');

      await controller().clearAll();

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, isEmpty);
      expect(fake.savedHistories.last.entries, isEmpty);
    });

    test('永続化失敗時も空の履歴を維持しpersistenceErrorへ遷移する', () async {
      await controller().recordSubmittedKeyword('flutter');
      const error = SearchHistoryPersistenceException(message: 'save failed');
      fake.saveError = error;

      await controller().clearAll();

      final current = state();
      expect(current.status, SearchHistoryStatus.persistenceError);
      expect(current.error, error);
      expect(current.history.entries, isEmpty);
    });

    test('loadが未完了の状態でも、以降の記録でdisk実体を積み直して復元しない', () async {
      // loadは呼ばない（未完了・未実行のまま）。disk上には過去の履歴が
      // あるとする。
      fake.loadResult = SearchHistory().recordSubmittedKeyword('old');

      await controller().clearAll();
      expect(state().history.entries, isEmpty);

      await controller().recordSubmittedKeyword('new');

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [SearchHistoryEntry('new')]);
      // clearAllの意図（空）を優先し、disk再読込を行っていないことを確認
      // する。読み込んでいれば'old'が復元されてしまう。
      expect(fake.loadCallCount, 0);
    });

    test('永続化失敗後の記録も、disk実体との統合を行わずメモリを基点にする', () async {
      fake.loadResult = SearchHistory().recordSubmittedKeyword('old');
      const error = SearchHistoryPersistenceException(message: 'save failed');
      fake.saveError = error;

      await controller().clearAll();
      expect(state().status, SearchHistoryStatus.persistenceError);

      fake.saveError = null;
      await controller().recordSubmittedKeyword('new');

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [SearchHistoryEntry('new')]);
      expect(fake.loadCallCount, 0);
    });
  });
}
