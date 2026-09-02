import 'dart:js_interop';

@JS('initializePostHogForFlutter')
external JSPromise<JSAny?> _initializePostHogForFlutter(
  JSString projectToken,
  JSString host,
);

Future<void> initializePostHogWeb({
  required String projectToken,
  required String host,
}) async {
  await _initializePostHogForFlutter(projectToken.toJS, host.toJS).toDart;
}
