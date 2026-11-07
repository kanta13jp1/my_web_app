import 'dart:io';
import 'inflow_fake_transaction_NONPRODUCTION_test.dart' as fixture;

// Synthetic negative control. This script must NOT be called a passing test.
void main() {
  try {
    fixture.check(false, 'intentional synthetic negative');
  } on StateError catch (error) {
    if (error.message != 'synthetic failure: intentional synthetic negative') {
      rethrow;
    }
    stdout.writeln('SYNTHETIC_EXPECTED_FAILURE');
    exitCode = 72;
    return;
  }
  throw StateError('negative control did not fail');
}