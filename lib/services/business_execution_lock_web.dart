import 'dart:js_interop';

@JS('navigator.locks')
external _ExecutionLockManager? get _lockManager;

extension type _ExecutionLockManager(JSObject _) implements JSObject {
  external JSPromise<JSAny?> request(JSString name, JSFunction callback);
}

/// Web Locks serializes every writer for this origin and account.
/// The browser releases the lock when the callback promise settles or the tab
/// closes. Unsupported/insecure environments fail closed, without writing.
Future<void> withBusinessExecutionLock(
  String name,
  Future<void> Function() action,
) async {
  final manager = _lockManager;
  if (manager == null) {
    throw UnsupportedError('Web Locksに対応したHTTPSブラウザーが必要です。');
  }
  (Object, StackTrace)? actionFailure;
  var actionCompleted = false;
  Future<JSAny?> runAction(JSAny? lock) async {
    try {
      if (lock == null) {
        throw StateError('排他ロックを取得できませんでした。');
      }
      await action();
      actionCompleted = true;
    } catch (error, stackTrace) {
      // Future.toJS boxes Dart failures in a JS Error. Keep the original Dart
      // objects here and settle the callback promise so the lock is released.
      actionFailure = (error, stackTrace);
    }
    return null;
  }

  final callback = ((JSAny? lock) => runAction(lock).toJS).toJS;
  // Request failures still propagate. Never report success without a lock.
  await manager.request(name.toJS, callback).toDart;
  final failure = actionFailure;
  if (failure != null) {
    Error.throwWithStackTrace(failure.$1, failure.$2);
  }
  if (!actionCompleted) {
    throw StateError('排他ロック内の保存処理が完了しませんでした。');
  }
}
