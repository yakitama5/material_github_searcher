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
    final gate = saveGate;
    if (gate != null) {
      await gate.future;
    }
    final error = saveError;
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

    test('起動時loadの完了前に記録されたkeywordをloadの結果で上書きしない', () async {
      final gate = Completer<void>();
      fake
        ..loadResult = SearchHistory().recordSubmittedKeyword('dart')
        ..loadGate = gate;

      // 起動時のload()が完了する前に、ユーザーがkeywordを送信したとする。
      final loadFuture = controller().load();
      await controller().recordSubmittedKeyword('flutter');
      expect(state().status, SearchHistoryStatus.ready);
      expect(state().history.entries, [SearchHistoryEntry('flutter')]);

      // load()を完了させる。dartを含む永続化済み履歴で、flutterの記録を
      // 巻き戻してはならない。
      gate.complete();
      await loadFuture;

      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [SearchHistoryEntry('flutter')]);
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
    });

    test('検索APIの成否に関わらず無条件で記録する', () async {
      // recordSubmittedKeywordは検索結果を引数に取らないため、
      // API成功・失敗・0件のいずれの文脈からでも同じ挙動で記録できる。
      await controller().recordSubmittedKeyword('no-results-keyword');

      expect(state().history.entries, [
        SearchHistoryEntry('no-results-keyword'),
      ]);
    });

    test('永続化失敗時も楽観更新した履歴は維持しpersistenceErrorへ遷移する', () async {
      const error = SearchHistoryPersistenceException(message: 'save failed');
      fake.saveError = error;

      await controller().recordSubmittedKeyword('flutter');

      final current = state();
      expect(current.status, SearchHistoryStatus.persistenceError);
      expect(current.error, error);
      expect(current.history.entries, [SearchHistoryEntry('flutter')]);
    });

    test('重複keywordは先頭へ移動して永続化する', () async {
      await controller().recordSubmittedKeyword('flutter');
      await controller().recordSubmittedKeyword('dart');
      await controller().recordSubmittedKeyword('flutter');

      expect(state().history.entries, [
        SearchHistoryEntry('flutter'),
        SearchHistoryEntry('dart'),
      ]);
      expect(fake.savedHistories, hasLength(3));
    });

    test('先発呼び出しの遅延失敗は後発が確定させた最新履歴を上書きしない', () async {
      final gate = Completer<void>();
      fake.saveGate = gate;

      // 先発(flutter)のsaveはgateで止め、後発(dart)より遅く完了させる。
      final future1 = controller().recordSubmittedKeyword('flutter');
      expect(state().history.entries, [SearchHistoryEntry('flutter')]);

      // 後発(dart)は即座に成功し、最新のreadyへ進む。
      fake.saveGate = null;
      await controller().recordSubmittedKeyword('dart');
      expect(state().status, SearchHistoryStatus.ready);
      expect(state().history.entries, [
        SearchHistoryEntry('dart'),
        SearchHistoryEntry('flutter'),
      ]);

      // 先発のsaveを失敗させて完了させる。
      const error = SearchHistoryPersistenceException(message: 'save failed');
      fake.saveError = error;
      gate.complete();
      await future1;

      // 先発の遅延失敗によって、後発が確定させた最新履歴が古いスナップ
      // ショット（dartを含まないflutterのみの履歴）へ巻き戻らない。
      final current = state();
      expect(current.status, SearchHistoryStatus.ready);
      expect(current.history.entries, [
        SearchHistoryEntry('dart'),
        SearchHistoryEntry('flutter'),
      ]);
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
  });
}
