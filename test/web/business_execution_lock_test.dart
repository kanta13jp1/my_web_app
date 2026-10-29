@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/business_execution_lock.dart';
import 'package:my_web_app/services/business_execution_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('exclusive browser lock serializes writers and releases after errors',
      () async {
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    var secondEntered = false;
    final first = withBusinessExecutionLock('execution-test', () async {
      firstEntered.complete();
      await releaseFirst.future;
      throw StateError('failure inside lock');
    });
    final handledFirst = expectLater(first, throwsStateError);
    await firstEntered.future;
    final second = withBusinessExecutionLock('execution-test', () async {
      secondEntered = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(secondEntered, isFalse);
    releaseFirst.complete();
    await handledFirst;
    await second;
    expect(secondEntered, isTrue);
  });

  test('two stale writers cannot both overwrite the same account snapshot',
      () async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalBusinessExecutionStore();
    Future<bool> attempt(String value) async {
      try {
        await store.write(
          'lock-test-account',
          null,
          value,
          isCurrent: () => true,
        );
        return true;
      } on StateError {
        return false;
      }
    }

    final results = await Future.wait([attempt('one'), attempt('two')]);
    expect(results.where((success) => success).length, 1);
    expect(await store.read('lock-test-account'), isIn(['one', 'two']));
  });
}
