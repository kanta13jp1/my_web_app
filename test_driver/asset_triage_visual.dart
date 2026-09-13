import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  final output = Directory('.ci-logs/asset-triage-visual');
  await output.create(recursive: true);
  await integrationDriver(
    driver: driver,
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name) || bytes.length < 8) {
        return false;
      }
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      final browser = await driver.webDriver.logs
          .get('browser')
          .map(
            (entry) => <String, Object?>{
              'level': entry.level,
              'message': entry.message,
              'timestamp': entry.timestamp.toIso8601String(),
            },
          )
          .toList();
      final network = <Map<String, Object?>>[];
      await for (final entry in driver.webDriver.logs.get('performance')) {
        final envelope =
            jsonDecode(entry.message ?? '{}') as Map<String, dynamic>;
        final message = envelope['message'] as Map<String, dynamic>?;
        final method = message?['method'];
        final params = message?['params'] as Map<String, dynamic>?;
        if (method == 'Network.loadingFailed') {
          network.add(<String, Object?>{
            'kind': 'request_failure',
            'error': params?['errorText'],
            'type': params?['type'],
          });
        }
        if (method == 'Network.responseReceived') {
          final response = params?['response'] as Map<String, dynamic>?;
          final status = response?['status'] as num?;
          if (status != null && status >= 500) {
            network
                .add(<String, Object?>{'kind': 'http_5xx', 'status': status});
          }
        }
      }
      await File('${output.path}/$name.json').writeAsString(
        jsonEncode(<String, Object?>{
          'capture': args,
          'browser': browser,
          'networkFailures': network,
          'scope': 'synthetic fixture; no authenticated persistence',
        }),
      );
      return true;
    },
    responseDataCallback: (data) async {
      stdout.writeln(jsonEncode(data));
    },
  );
}
