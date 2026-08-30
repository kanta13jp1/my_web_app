import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web index includes the inert sandbox bridge', () {
    final html = File('web/index.html').readAsStringSync();

    expect(
      html,
      contains('<script src="paddle_sandbox_bridge.js" defer></script>'),
    );
    expect(html, isNot(contains('cdn.paddle.com/paddle/v2/paddle.js')));
  });

  test(
    'bridge is sandbox-only and initializes Paddle in the required order',
    () {
      final bridge = File('web/paddle_sandbox_bridge.js').readAsStringSync();

      expect(bridge, contains('https://cdn.paddle.com/paddle/v2/paddle.js'));
      expect(bridge, contains(r'/^test_[a-zA-Z0-9]{27}$/'));
      expect(bridge, isNot(contains('live_')));
      expect(bridge, isNot(contains('apiKey')));
      expect(
        bridge.indexOf("paddle.Environment.set('sandbox')"),
        lessThan(bridge.indexOf('paddle.Initialize({')),
      );
      expect(bridge, contains('showAddTaxId: true'));
      expect(
        bridge,
        contains('parsedSuccessUrl.origin !== window.location.origin'),
      );
    },
  );

  test('bridge forwards only the event result needed by Flutter', () {
    final bridge = File('web/paddle_sandbox_bridge.js').readAsStringSync();

    expect(bridge, contains('eventSink(eventName, transactionId, message)'));
    expect(bridge, isNot(contains('eventSink(event)')));
  });
}
