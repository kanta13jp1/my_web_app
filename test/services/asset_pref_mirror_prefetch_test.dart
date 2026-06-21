import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_pref_mirror_prefetch.dart';

void main() {
  group('indexPrefMirrorRowsByKey', () {
    test('empty input returns empty map', () {
      expect(indexPrefMirrorRowsByKey(const <dynamic>[]), isEmpty);
    });

    test('indexes rows by pref_key preserving the full row', () {
      final map = indexPrefMirrorRowsByKey(<dynamic>[
        <String, dynamic>{
          'pref_key': 'salary_day',
          'value': 25,
          'updated_at': '2026-06-21T00:00:00Z',
        },
        <String, dynamic>{
          'pref_key': 'main_account',
          'value': <String, dynamic>{'id': 'a'},
        },
      ]);
      expect(map.keys, containsAll(<String>['salary_day', 'main_account']));
      expect(map['salary_day']!['value'], 25);
      expect(map['salary_day']!['updated_at'], '2026-06-21T00:00:00Z');
      expect(map['main_account']!['value'], <String, dynamic>{'id': 'a'});
    });

    test('skips rows that are not maps or lack a pref_key', () {
      final map = indexPrefMirrorRowsByKey(<dynamic>[
        'not a map',
        <String, dynamic>{'value': 1}, // pref_key 欠落
        <String, dynamic>{'pref_key': '', 'value': 2}, // 空キー
        <String, dynamic>{'pref_key': 'ok', 'value': 3},
      ]);
      expect(map.keys, <String>['ok']);
      expect(map['ok']!['value'], 3);
    });

    test('last row wins for a duplicated pref_key', () {
      final map = indexPrefMirrorRowsByKey(<dynamic>[
        <String, dynamic>{'pref_key': 'k', 'value': 1},
        <String, dynamic>{'pref_key': 'k', 'value': 2},
      ]);
      expect(map['k']!['value'], 2);
    });

    test('returned row is a defensive copy', () {
      final source = <String, dynamic>{'pref_key': 'k', 'value': 1};
      final map = indexPrefMirrorRowsByKey(<dynamic>[source]);
      map['k']!['value'] = 99;
      expect(source['value'], 1);
    });
  });
}
