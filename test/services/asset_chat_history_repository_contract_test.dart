import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/services/asset_chat_history_repository.dart',
  ).readAsStringSync();

  test('list query is owner-scoped, column-bounded, and paginated', () {
    expect(source, contains('.select(threadColumns)'));
    expect(source, contains('.eq(\'user_id\', userId)'));
    expect(source, contains('.ilike(\'title\''));
    expect(source, contains('.range(safeOffset, safeOffset + safeLimit)'));
    expect(source, isNot(contains('.select(\'*\')')));
  });

  test('message detail is lazy and thread deletion is doubly scoped', () {
    expect(source, contains('.select(messageColumns)'));
    expect(source, contains('.eq(\'thread_id\', normalizedThreadId)'));
    expect(source, contains('.delete()'));
    expect(source, contains('.eq(\'id\', normalizedThreadId)'));
    expect(source, contains('.eq(\'user_id\', userId)'));
    expect(source, contains('.select(\'id\')'));
  });
}
