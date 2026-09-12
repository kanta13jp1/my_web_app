import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/auto_save_service.dart';

void main() {
  late AutoSaveService service;
  var disposed = false;

  setUp(() {
    service = AutoSaveService();
    disposed = false;
  });

  tearDown(() {
    if (!disposed) service.dispose();
  });

  void disposeService() {
    service.dispose();
    disposed = true;
  }

  testWidgets('debounce keeps only the latest requested save', (tester) async {
    final calls = <String>[];
    service.triggerAutoSave(() async => calls.add('old'));
    await tester.pump(const Duration(seconds: 1));
    service.triggerAutoSave(() async => calls.add('latest'));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['latest']);
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('manual saves never overlap and cancel pending debounce',
      (tester) async {
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    final calls = <String>[];
    service.triggerAutoSave(() async => calls.add('debounced'));
    final first = service.saveImmediately(() async {
      calls.add('first-start');
      await firstGate.future;
      calls.add('first-end');
    });
    final second = service.saveImmediately(() async {
      calls.add('second-start');
      await secondGate.future;
      calls.add('second-end');
    });
    await tester.pump(const Duration(seconds: 3));
    expect(calls, ['first-start']);
    firstGate.complete();
    await tester.pump();
    expect(calls, ['first-start', 'first-end', 'second-start']);
    secondGate.complete();
    await tester.pump();
    await Future.wait([first, second]);
    expect(calls.last, 'second-end');
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('old completion cannot mark newer debounced input saved',
      (tester) async {
    final gate = Completer<void>();
    var latestCalls = 0;
    final first = service.saveImmediately(() => gate.future);
    await tester.pump();
    service.triggerAutoSave(() async => latestCalls++);
    gate.complete();
    await tester.pump();
    await first;
    expect(service.saveState, SaveState.modified);
    expect(service.lastSavedTime, isNull);
    expect(latestCalls, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(latestCalls, 1);
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('elapsed debounce queues behind an in-flight request',
      (tester) async {
    final gate = Completer<void>();
    final calls = <String>[];
    final first = service.saveImmediately(() async {
      calls.add('first');
      await gate.future;
    });
    await tester.pump();
    service.triggerAutoSave(() async => calls.add('latest'));
    await tester.pump(const Duration(seconds: 3));
    expect(calls, ['first']);
    gate.complete();
    await tester.pump();
    await first;
    expect(calls, ['first', 'latest']);
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('superseded queued autosaves cannot run an old callback',
      (tester) async {
    final gate = Completer<void>();
    final calls = <String>[];
    final hold = service.runExclusive(() => gate.future);
    await tester.pump();
    service.triggerAutoSave(() async => calls.add('stale'));
    await tester.pump(const Duration(seconds: 2));
    service.triggerAutoSave(() async => calls.add('latest'));
    gate.complete();
    await tester.pump();
    await hold;
    expect(calls, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, ['latest']);
  });

  testWidgets('automatic failure retries the current draft once it can save',
      (tester) async {
    var attempts = 0;
    service.triggerAutoSave(() async {
      attempts++;
      if (attempts == 1) throw StateError('synthetic failure');
    });
    await tester.pump(const Duration(seconds: 2));
    expect(attempts, 1);
    expect(service.saveState, SaveState.error);
    await tester.pump(const Duration(seconds: 4));
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 2);
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('failure from older request does not retry over a newer edit',
      (tester) async {
    final gate = Completer<void>();
    var oldCalls = 0;
    var latestCalls = 0;
    service.triggerAutoSave(() async {
      oldCalls++;
      await gate.future;
    });
    await tester.pump(const Duration(seconds: 2));
    service.triggerAutoSave(() async => latestCalls++);
    gate.completeError(StateError('old request failed'));
    await tester.pump();
    expect(service.saveState, SaveState.modified);
    await tester.pump(const Duration(seconds: 8));
    expect(oldCalls, 1);
    expect(latestCalls, 1);
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('manual failure reaches caller and does not poison the lane',
      (tester) async {
    var attempts = 0;
    final failure = expectLater(
      service.saveImmediately(() async {
        attempts++;
        throw StateError('manual failure');
      }),
      throwsStateError,
    );
    await tester.pump();
    await failure;
    expect(service.saveState, SaveState.error);
    await tester.pump(const Duration(seconds: 8));
    expect(attempts, 1);
    final next = service.saveImmediately(() async => attempts++);
    await tester.pump();
    await next;
    expect(attempts, 2);
    expect(service.saveState, SaveState.saved);
  });

  testWidgets('exclusive recovery holds later saves until it finishes',
      (tester) async {
    final gate = Completer<void>();
    final calls = <String>[];
    final recovery = service.runExclusive(() async {
      calls.add('backup');
      await gate.future;
      calls.add('apply');
      return 'selected revision';
    });
    await tester.pump();
    service.triggerAutoSave(() async => calls.add('save'));
    await tester.pump(const Duration(seconds: 3));
    expect(calls, ['backup']);
    gate.complete();
    await tester.pump();
    expect(await recovery, 'selected revision');
    expect(calls, ['backup', 'apply', 'save']);
  });

  testWidgets('failed recovery releases the lane for the next save',
      (tester) async {
    final failure = expectLater(
      service.runExclusive<void>(() async {
        throw StateError('backup failed');
      }),
      throwsStateError,
    );
    var saved = false;
    final next = service.saveImmediately(() async => saved = true);
    await tester.pump();
    await failure;
    await next;
    expect(saved, isTrue);
  });

  testWidgets('final save runs last after disposal without queued UI callbacks',
      (tester) async {
    final gate = Completer<void>();
    final calls = <String>[];
    var notifications = 0;
    service.addListener(() => notifications++);
    final first = service.saveImmediately(() async {
      calls.add('first-start');
      await gate.future;
      calls.add('first-end');
    });
    await tester.pump();
    final skipped = service.saveImmediately(() async => calls.add('queued-ui'));
    final finalSave =
        service.saveOnExit(() async => calls.add('final-capture'));
    final beforeDispose = notifications;
    disposeService();
    gate.complete();
    await tester.pump(const Duration(seconds: 10));
    await Future.wait([first, skipped, finalSave]);
    expect(calls, ['first-start', 'first-end', 'final-capture']);
    expect(notifications, beforeDispose);
  });

  testWidgets('disposal suppresses debounce and late completion notifications',
      (tester) async {
    final gate = Completer<void>();
    var queued = 0;
    var notifications = 0;
    service.addListener(() => notifications++);
    final saving = service.saveImmediately(() => gate.future);
    await tester.pump();
    service.triggerAutoSave(() async => queued++);
    final beforeDispose = notifications;
    disposeService();
    gate.complete();
    await tester.pump(const Duration(seconds: 10));
    await saving;
    expect(queued, 0);
    expect(notifications, beforeDispose);
  });

  testWidgets('callback-reported unsaved state is not overwritten on return',
      (tester) async {
    final saving = service.saveImmediately(() async {
      service.markAsModified();
    });
    await tester.pump();
    await saving;
    expect(service.saveState, SaveState.modified);
    expect(service.lastSavedTime, isNull);
  });
}
