import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_subscription_audit_mutation_queue.dart';

void main() {
  test('restore reads the committed decision after delayed persistence',
      () async {
    final queue = AssetSubscriptionAuditMutationQueue();
    final persistence = Completer<void>();
    final started = Completer<void>();
    final state = <String, int>{};
    final disk = <String, int>{};
    final events = <String>[];
    final decision = queue.run(() async {
      events.add('decision started');
      started.complete();
      await persistence.future;
      disk['apple'] = 2;
      state['apple'] = 2;
      events.add('decision committed');
    });
    await started.future;
    final restore = queue.run(() async {
      events.add('restore started');
      final newer = state['apple'] ?? 0;
      disk['apple'] = newer > 1 ? newer : 1;
      state['apple'] = disk['apple']!;
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, <String>['decision started']);
    expect(state, isEmpty);
    persistence.complete();
    await Future.wait(<Future<void>>[decision, restore]);
    expect(events, <String>[
      'decision started',
      'decision committed',
      'restore started',
    ]);
    expect(state['apple'], 2);
    expect(disk['apple'], 2);
  });

  test('a rejected save does not poison the next operation', () async {
    final queue = AssetSubscriptionAuditMutationQueue();
    final failed = queue.run<void>(() async => throw StateError('rejected'));
    final failure = expectLater(failed, throwsStateError);
    var recovered = false;
    final next = queue.run(() async {
      recovered = true;
    });
    await failure;
    await next;
    expect(recovered, isTrue);
  });

  test('each caller receives its own queued result', () async {
    final queue = AssetSubscriptionAuditMutationQueue();
    final first = queue.run(() async => 7);
    final second = queue.run(() async => 9);
    expect(await first, 7);
    expect(await second, 9);
  });
}
