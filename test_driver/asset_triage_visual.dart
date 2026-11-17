import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

String _requestLocation(Object? value) {
  if (value is! String) return 'unknown';
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return 'non-http';
  }
  return '${uri.origin}${uri.path}';
}

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  final output = Directory('.ci-logs/asset-triage-visual');
  await output.create(recursive: true);
  final requestLocations = <String, String>{};
  await integrationDriver(
    driver: driver,
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name) || bytes.length < 24) {
        return false;
      }
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      final header = ByteData.sublistView(Uint8List.fromList(bytes));
      final pixelWidth = header.getUint32(16);
      final pixelHeight = header.getUint32(20);
      final ratio = (args?['devicePixelRatio'] as num?) ?? 1;
      final expectedWidth = ((args?['width'] as num?) ?? 0) * ratio;
      final expectedHeight = ((args?['height'] as num?) ?? 0) * ratio;
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
        final requestId = params?['requestId'];
        if (method == 'Network.requestWillBeSent' && requestId is String) {
          final request = params?['request'] as Map<String, dynamic>?;
          requestLocations[requestId] = _requestLocation(request?['url']);
        }
        if (method == 'Network.loadingFinished') {
          requestLocations.remove(requestId);
        }
        if (method == 'Network.loadingFailed') {
          network.add(<String, Object?>{
            'kind': 'request_failure',
            'url': requestLocations.remove(requestId) ?? 'unknown',
            'error': params?['errorText'],
            'type': params?['type'],
          });
        }
        if (method == 'Network.responseReceived') {
          final response = params?['response'] as Map<String, dynamic>?;
          final status = response?['status'] as num?;
          if (status != null && status >= 500) {
            network.add(<String, Object?>{
              'kind': 'http_5xx',
              'status': status,
              'url': _requestLocation(response?['url']),
            });
          }
        }
      }
      await File('${output.path}/$name.json').writeAsString(
        jsonEncode(<String, Object?>{
          'capture': args,
          'pixelWidth': pixelWidth,
          'pixelHeight': pixelHeight,
          'browser': browser,
          'networkFailures': network,
          'scope': 'synthetic fixture; no authenticated persistence',
        }),
      );
      return (pixelWidth - expectedWidth).abs() <= 1 &&
          (pixelHeight - expectedHeight).abs() <= 1;
    },
    responseDataCallback: (data) async {
      stdout.writeln(jsonEncode(data));
    },
  );
}
