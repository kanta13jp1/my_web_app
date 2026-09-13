// Test-only entrypoint. Default lib/main.dart never imports this file.
// Runs the unchanged application, with one bridge to its REAL Auth signOut.
import 'dart:js_interop';

import 'package:my_web_app/main.dart' as application;
import 'package:supabase_flutter/supabase_flutter.dart';

@JS('hexcivIsolatedSignOut')
external set isolatedSignOut(JSFunction callback);

JSPromise<JSAny?> signOut() {
  return Supabase.instance.client.auth.signOut().then<JSAny?>((_) => null).toJS;
}

Future<void> main() async {
  const environment = String.fromEnvironment('ENVIRONMENT');
  const endpoint = String.fromEnvironment('SUPABASE_URL');
  if (environment != 'isolated-auth-test' ||
      endpoint != 'http://127.0.0.1:54321' ||
      Uri.base.origin != 'http://127.0.0.1:7357') {
    throw StateError('The test entrypoint may only run on isolated loopback');
  }
  await application.main();
  isolatedSignOut = signOut.toJS;
}
