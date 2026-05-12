// VM-only stubs for dart:js_interop — compile-only, never executed at runtime on VM.
// Imported when dart.library.io is available (= Dart VM / flutter test --coverage).
// On web/wasm, dart:js_interop itself is imported instead (see conditional import).

typedef JSObject = Object;
typedef JSString = String;
typedef JSArray<T> = List<T>;
typedef JSFunction = Object;
typedef JSArrayBuffer = Object;
typedef JSUint8Array = Object;
typedef JSAny = Object;

extension JsInteropObjectStub on Object? {
  Object? get toJS => this;
}

extension JsInteropListStub<T> on List<T> {
  List<T> get toJS => this;
}
