import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

/// `[from, to]` (両端含む) を PostgREST と同じ意味で切り出す擬似サーバ。
/// [maxRows] は PostgREST の max-rows 上限 (既定 1000) を模す。
List<Map<String, dynamic>> _serve(
  List<Map<String, dynamic>> all,
  int from,
  int to, {
  int maxRows = 1000,
}) {
  if (from >= all.length) {
    return <Map<String, dynamic>>[];
  }
  final requested = to - from + 1;
  final capped = requested > maxRows ? maxRows : requested;
  final end = (from + capped) > all.length ? all.length : from + capped;
  return all.sublist(from, end);
}

List<Map<String, dynamic>> _rows(int n) =>
    List.generate(n, (i) => <String, dynamic>{'id': 'id-$i'});

void main() {
  group('fetchAllPagedRows', () {
    test('fetches every row when the table exceeds one page', () async {
      final all = _rows(3695);
      var calls = 0;
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          calls++;
          return _serve(all, from, to);
        },
      );

      // 打ち切られず 3695 件すべて取得できる (回帰の本体)。
      expect(result.length, 3695);
      expect(result.first['id'], 'id-0');
      expect(result.last['id'], 'id-3694');
      expect(calls, 4); // 1000*3 + 695
    });

    test('rows are returned in page order without gaps or duplicates',
        () async {
      final all = _rows(2500);
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async => _serve(all, from, to),
      );

      expect(result.map((r) => r['id']).toList(), all.map((r) => r['id']));
      expect(result.map((r) => r['id']).toSet().length, 2500);
    });

    test('stops after a single call when the table fits in one page', () async {
      final all = _rows(42);
      var calls = 0;
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          calls++;
          return _serve(all, from, to);
        },
      );

      expect(result.length, 42);
      expect(calls, 1);
    });

    test('exact multiple of pageSize needs one extra empty page', () async {
      final all = _rows(2000);
      var calls = 0;
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          calls++;
          return _serve(all, from, to);
        },
      );

      expect(result.length, 2000);
      // 2 ページ満杯 → 終端判定のため 3 回目 (空) が必要。
      expect(calls, 3);
    });

    test('empty table yields empty result with one call', () async {
      var calls = 0;
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          calls++;
          return <Map<String, dynamic>>[];
        },
      );

      expect(result, isEmpty);
      expect(calls, 1);
    });

    test('maxRows caps the fetch and prevents runaway loops', () async {
      final all = _rows(100000);
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async => _serve(all, from, to),
        maxRows: 2500,
      );

      expect(result.length, 2500);
    });

    test('respects a custom pageSize', () async {
      final all = _rows(250);
      var calls = 0;
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          calls++;
          // ページサイズが要求どおり渡っていること。
          expect(to - from + 1, lessThanOrEqualTo(100));
          return _serve(all, from, to, maxRows: 100);
        },
        pageSize: 100,
      );

      expect(result.length, 250);
      expect(calls, 3);
    });

    test('a short page ends pagination even mid-table (server truncation)',
        () async {
      // サーバが要求より少なく返したら最終ページとみなす。
      var calls = 0;
      final result = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          calls++;
          return _rows(10); // 常に 10 件 (< pageSize) → 1 回で終了
        },
      );

      expect(result.length, 10);
      expect(calls, 1);
    });
  });
}
