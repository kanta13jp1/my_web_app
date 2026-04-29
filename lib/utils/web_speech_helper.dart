// Conditional export: web implementation on browser, stub on VM
export 'web_speech_helper_stub.dart'
    if (dart.library.js_interop) 'web_speech_helper_web.dart';
