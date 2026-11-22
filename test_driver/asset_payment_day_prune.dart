import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  stdout.writeln('SYNTHETIC_PRUNE_DRIVER: waiting');
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      stdout.writeln(jsonEncode(data));
      final errors = data?['frameworkErrors'];
      if (errors != null && (errors is! List || errors.isNotEmpty)) {
        throw StateError('synthetic browser reported framework errors');
      }
      if (data?['pruneCasesCompleted'] != 3) {
        throw StateError('expected three completed synthetic prune cases');
      }
    },
  );
  stdout.writeln('SYNTHETIC_PRUNE_DRIVER: complete');
}
