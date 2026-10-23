import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_calendar_reflection_import_parser.dart';

void main() {
  Map<String, dynamic> row(String key) => {
        'source_key': key,
        'occurred_on': '2026-10-21',
        'kinds': ['reading'],
        'title': '日本語の書名',
        'source_label': '合成検査',
        'memo': List.filled(2000, 'あ').join(),
      };

  test('long Japanese batch preserves every title and source', () {
    final input = jsonEncode(List.generate(16, (i) => row('test:$i')));
    final parsed = parseAssetCalendarReflectionImport(input);
    expect(parsed, hasLength(16));
    expect(parsed.first.title, '日本語の書名');
    expect(parsed.last.sourceLabel, '合成検査');
    expect(parsed.first.memo.length, 2000);
    expect(parseAssetCalendarReflectionImport(input), hasLength(16));
  });

  test('syntax error exposes position without echoing input', () {
    expect(
      () => parseAssetCalendarReflectionImport('[private-content'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('JSONの構文'), isNot(contains('private-content'))),
        ),
      ),
    );
  });

  test('row errors identify record and correction remains possible', () {
    final invalid = row('test:2')..['memo'] = List.filled(2001, 'あ').join();
    expect(
      () => parseAssetCalendarReflectionImport(
        jsonEncode([row('test:1'), invalid]),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('2件目: メモが長すぎます'),
        ),
      ),
    );
    invalid['memo'] = '訂正';
    expect(
      parseAssetCalendarReflectionImport(jsonEncode([row('test:1'), invalid])),
      hasLength(2),
    );
  });

  test('non-object and duplicate source identify record', () {
    for (final data in [
      [row('same'), 1],
      [row('same'), row('same')],
    ]) {
      expect(
        () => parseAssetCalendarReflectionImport(jsonEncode(data)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('2件目:'),
          ),
        ),
      );
    }
  });
}
