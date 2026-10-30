@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/business_execution_lock.dart';
import 'package:my_web_app/services/business_execution_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

@JS('navigator')
external JSObject get _navigator;

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _ownDescriptor(JSObject target, JSString property);

@JS('Object.defineProperty')
external void _defineProperty(
  JSObject target,
  JSString property,
  JSObject descriptor,
);

@JS('Reflect.deleteProperty')
external bool _deleteProperty(JSObject target, JSString property);

Future<void> withFakeLocks(
  JSObject? locks,
  Future<void> Function() action,
) async {
  final property = 'locks'.toJS;
  final original = _ownDescriptor(_navigator, property);
  final descriptor = <String, Object?>{
    'value': locks,
    'configurable': true,
  }.jsify() as JSObject;
  _defineProperty(_navigator, property, descriptor);
  try {
    await action();
  } finally {
    if (original == null) {
      expect(_deleteProperty(_navigator, property), isTrue);
    } else {
      _defineProperty(_navigator, property, original);
    }
  }
}

Future<void> expectOriginalFailure(
  Future<void> operation,
  Object expectedError,
  StackTrace expectedStack,
) async {
  Object? caughtError;
  StackTrace? caughtStack;
  try {
    await operation;
  } catch (error, stackTrace) {
    caughtError = error;
    caughtStack = stackTrace;
  }
  expect(caughtError, same(expectedError));
  expect(caughtStack?.toString(), expectedStack.toString());
}

void main() {
  test('exclusive browser lock serializes writers and releases after errors',
      () async {
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    var secondEntered = false;
    final failure = StateError('failure inside lock');
    final failureStack = StackTrace.fromString('async-lock-failure');
    final first = withBusinessExecutionLock('execution-test', () async {
      firstEntered.complete();
      await releaseFirst.future;
      Error.throwWithStackTrace(failure, failureStack);
    });
    final handledFirst = expectOriginalFailure(first, failure, failureStack);
    await firstEntered.future;
    final second = withBusinessExecutionLock('execution-test', () async {
      secondEntered = true;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(secondEntered, isFalse);
    } finally {
      releaseFirst.complete();
    }
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

  test('synchronous callback error keeps its value and releases the lock',
      () async {
    final failure = ArgumentError.value('sentinel', 'actual', 'invalid');
    final failureStack = StackTrace.fromString('sync-lock-failure');
    await expectOriginalFailure(
      withBusinessExecutionLock('execution-sync-test', () {
        Error.throwWithStackTrace(failure, failureStack);
      }),
      failure,
      failureStack,
    );
    var nextEntered = false;
    await withBusinessExecutionLock('execution-sync-test', () async {
      nextEntered = true;
    });
    expect(nextEntered, isTrue);
  });

  test('missing Web Locks rejects without invoking the action', () async {
    await withFakeLocks(null, () async {
      var entered = false;
      await expectLater(
        withBusinessExecutionLock('missing-locks', () async {
          entered = true;
        }),
        throwsA(isA<UnsupportedError>()),
      );
      expect(entered, isFalse);
    });
  });

  test('a rejected lock request cannot invoke or report a successful action',
      () async {
    final manager = JSObject();
    manager['request'] = ((JSString name, JSFunction callback) {
      return JSPromise<JSAny?>(
        ((JSFunction resolve, JSFunction reject) {
          reject.callAsFunction(null, 'request rejected'.toJS);
        }).toJS,
      );
    }).toJS;
    await withFakeLocks(manager, () async {
      var entered = false;
      await expectLater(
        withBusinessExecutionLock('rejected-lock', () async {
          entered = true;
        }),
        throwsA(anything),
      );
      expect(entered, isFalse);
    });
  });

  test('a null lock cannot invoke or report a successful action', () async {
    final manager = JSObject();
    manager['request'] = ((JSString name, JSFunction callback) {
      return callback.callAsFunction(null, null);
    }).toJS;
    await withFakeLocks(manager, () async {
      var entered = false;
      await expectLater(
        withBusinessExecutionLock('null-lock', () async {
          entered = true;
        }),
        throwsStateError,
      );
      expect(entered, isFalse);
    });
  });

  test('a request that skips its callback cannot report success', () async {
    final manager = JSObject();
    manager['request'] = ((JSString name, JSFunction callback) {
      return Future<JSAny?>.value(null).toJS;
    }).toJS;
    await withFakeLocks(manager, () async {
      var entered = false;
      await expectLater(
        withBusinessExecutionLock('skipped-lock', () async {
          entered = true;
        }),
        throwsStateError,
      );
      expect(entered, isFalse);
    });
  });
}
