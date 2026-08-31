import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web entrypoint loads the local Paddle sandbox bridge', () {
    final index = File('web/index.html').readAsStringSync();
    final bridge = File('web/paddle_sandbox_bridge.js').readAsStringSync();
    const paddleTag = '<script src="paddle_sandbox_bridge.js"></script>';
    const bootstrapTag = '<script src="flutter_bootstrap.js" async></script>';

    expect(index, contains(paddleTag));
    expect(index, contains(bootstrapTag));
    expect(
      index.indexOf(paddleTag),
      lessThan(index.indexOf(bootstrapTag)),
    );
    expect(bridge, contains('https://cdn.paddle.com/paddle/v2/paddle.js'));
    expect(bridge, contains("paddle.Environment.set('sandbox')"));
    expect(bridge, contains('paddle.Initialize({'));
    expect(bridge, contains('paddle.Checkout.open({'));
    expect(bridge, contains('window.getPaddleSandboxEventLog'));
    expect(bridge, contains('receivedAt: new Date().toISOString()'));
  });
}
