import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('only an explicit PostgREST serialization error proves rejection', () {
    expect(
      isPayrollSnapshotDefiniteConflict(
        const PostgrestException(message: 'synthetic conflict', code: '40001'),
      ),
      isTrue,
    );
    for (final error in <Object>[
      const PostgrestException(message: 'synthetic', code: '57014'),
      const PostgrestException(message: 'synthetic', code: '40P01'),
      const PostgrestException(message: '40001'),
      TimeoutException('40001'),
      StateError('40001'),
    ]) {
      expect(isPayrollSnapshotDefiniteConflict(error), isFalse);
    }
  });
}
