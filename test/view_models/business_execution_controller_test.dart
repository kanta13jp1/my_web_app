import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/business_execution.dart';
import 'package:my_web_app/services/business_execution_store.dart';
import 'package:my_web_app/view_models/business_execution_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_execution_test.dart' as fixtures;

class MemoryExecutionStore implements BusinessExecutionStore {
  final data = <String, String>{};
  bool failWrite = false;
  Completer<String?>? pendingRead;

  @override
  Future<String?> read(String userId) async =>
      pendingRead == null ? data[userId] : pendingRead!.future;

  @override
  Future<void> write(String userId, String? expected, String value) async {
    if (failWrite || data[userId] != expected) throw StateError('save failed');
    data[userId] = value;
  }
}

Future<void> testExecutionLock(
  String name,
  Future<void> Function() action,
) => action();

void main() {
  test('save readback, failure retention, retry and future-day rejection', () async {
    final store = MemoryExecutionStore();
    final controller = BusinessExecutionController(
      userId: 'a',
      currentUserId: () => 'a',
      store: store,
      now: () => DateTime(2026, 10, 30),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(await controller.add(fixtures.plan()), isTrue);
    store.failWrite = true;
    expect(
      await controller.report(
        'plan',
        '2026-10-30',
        BusinessDailyReport(actual: 0, note: '残す'),
      ),
      isFalse,
    );
    expect(controller.plans.single.reports, isEmpty);
    expect(controller.error, isNotNull);
    store.failWrite = false;
    expect(
      await controller.report(
        'plan',
        '2026-10-30',
        BusinessDailyReport(actual: 0, note: '残す'),
      ),
      isTrue,
    );
    expect(
      await controller.report(
        'plan',
        '2026-10-31',
        BusinessDailyReport(actual: 1, note: ''),
      ),
      isFalse,
    );
    await controller.load();
    expect(controller.plans.single.reports['2026-10-30']!.actual, 0);
  });

  test('late load after account switch is ignored and cannot save', () async {
    var currentUser = 'a';
    final store = MemoryExecutionStore()..pendingRead = Completer<String?>();
    final controller = BusinessExecutionController(
      userId: 'a',
      currentUserId: () => currentUser,
      store: store,
    );
    addTearDown(controller.dispose);
    final loading = controller.load();
    currentUser = 'b';
    store.pendingRead!.complete(
      BusinessExecutionCodec.encode([fixtures.plan()]),
    );
    await loading;
    expect(controller.plans, isEmpty);
    expect(await controller.add(fixtures.plan()), isFalse);
    expect(store.data, isEmpty);
  });

  test('corrupt storage fails closed without resetting saved data', () async {
    final store = MemoryExecutionStore()..data['a'] = '{broken';
    final controller = BusinessExecutionController(
      userId: 'a',
      currentUserId: () => 'a',
      store: store,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.ready, isFalse);
    expect(await controller.add(fixtures.plan()), isFalse);
    expect(store.data['a'], '{broken');
  });

  test('device store separates accounts and refuses stale overwrite', () async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalBusinessExecutionStore(withLock: testExecutionLock);
    final raw = BusinessExecutionCodec.encode([fixtures.plan()]);
    await store.write('a', null, raw);
    expect(await store.read('a'), raw);
    expect(await store.read('b'), isNull);
    await expectLater(store.write('a', null, 'other'), throwsStateError);
    expect(await store.read('a'), raw);
  });
  test('archive retains history and permits the next active plan', () async {
    final store = MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode(
        List.generate(24, (index) => fixtures.plan(id: '$index')),
      );
    final controller = BusinessExecutionController(
      userId: 'a',
      currentUserId: () => 'a',
      store: store,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(await controller.add(fixtures.plan(id: 'next')), isFalse);
    expect(await controller.setArchived('0', true), isTrue);
    expect(await controller.add(fixtures.plan(id: 'next')), isTrue);
    await controller.load();
    expect(controller.plans.length, 25);
    expect(controller.plans.first.archived, isTrue);
    expect(await controller.setArchived('0', false), isFalse);
  });

}
