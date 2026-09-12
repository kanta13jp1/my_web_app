import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('batch generation and history stay scoped to the authenticated user',
      () {
    final source = File(
      'supabase/functions/viral-video-ad-generator/index.ts',
    ).readAsStringSync();

    expect(source, contains('admin.auth.getUser'));
    expect(source, contains('.eq("user_id", authenticatedUserId)'));
    expect(source, contains('hedraBatchGenerationId is required'));
    expect(source, contains('confirmBatchCost=true is required'));
    expect(source, contains('Hedra batch group not found'));
    expect(source, contains('user_id: authenticatedUserId'));
  });
}
