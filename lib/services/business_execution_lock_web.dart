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
  final callback = ((JSAny? lock) {
    return action().then<JSAny?>((_) => null).toJS;
  }).toJS;
  await manager.request(name.toJS, callback).toDart;
}
