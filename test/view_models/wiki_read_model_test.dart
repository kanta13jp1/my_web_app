import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/repositories/wiki_repository.dart';
import 'package:my_web_app/view_models/wiki_read_model.dart';

void main() {
  test('append failure preserves pages and retries the same offset', () async {
    var failNext = true;
    final offsets = <int>[];
    final model = WikiReadModel(
      WikiRepository((body) async {
        offsets.add(body['offset'] as int);
        if (body['offset'] == 0) {
          return {
            'success': true,
            'pages': List.generate(50, (n) => {'id': 'p-$n'}),
            'next_offset': 50,
          };
        }
        if (failNext) {
          failNext = false;
          throw StateError('offline');
        }
        return {
          'success': true,
          'pages': [
            {'id': 'p-50'},
          ],
          'next_offset': null,
        };
      }),
    );
    addTearDown(model.dispose);
    await model.refresh();
    await model.loadMore();
    expect(model.pages.length, 50);
    expect(model.error, isNotNull);
    expect(model.nextOffset, 50);
    await model.loadMore();
    expect(model.pages.length, 51);
    expect(model.error, isNull);
    expect(offsets, [0, 50, 50]);
  });

  test('late detail response cannot replace a newer selection', () async {
    final a = Completer<dynamic>();
    final b = Completer<dynamic>();
    final model = WikiReadModel(
      WikiRepository((body) => body['id'] == 'a' ? a.future : b.future),
    );
    addTearDown(model.dispose);
    final first = model.select('a');
    final second = model.select('b');
    b.complete({
      'success': true,
      'page': {'id': 'b'},
      'children': [
        {'id': 'b-child'},
      ],
      'table_rows': [
        {'id': 'b-row', 'content': 'B row'},
      ],
    });
    await second;
    a.complete({
      'success': true,
      'page': {'id': 'a'},
      'children': [
        {'id': 'a-child'},
      ],
      'table_rows': [
        {'id': 'a-row', 'content': 'A row'},
      ],
    });
    await first;
    expect(model.selectedId, 'b');
    expect(model.selectedPage!['id'], 'b');
    expect(model.children.single['id'], 'b-child');
    expect(model.tableRows.single['id'], 'b-row');
    expect(model.detailLoading, isFalse);
  });

  test('select populates detail children, rows, flags, and clears on error',
      () async {
    var shouldFail = false;
    final model = WikiReadModel(
      WikiRepository((body) async {
        if (shouldFail) throw StateError('offline');
        return {
          'success': true,
          'page': {'id': body['id']},
          'children': [
            {
              'id': 'c1',
              'metadata': {'title': 'Child 1'},
            },
          ],
          'children_has_more': true,
          'table_rows': [
            {
              'id': 'r1',
              'metadata': {
                'data': {'content': 'Row 1'},
              },
            },
          ],
          'table_rows_has_more': true,
        };
      }),
    );
    addTearDown(model.dispose);
    await model.select('a');
    expect(model.children.single['title'], 'Child 1');
    expect(model.tableRows.single['content'], 'Row 1');
    expect(model.childrenHasMore, isTrue);
    expect(model.tableRowsHasMore, isTrue);

    shouldFail = true;
    await model.select('b');
    expect(model.detailError, isNotNull);
    expect(model.children, isEmpty);
    expect(model.tableRows, isEmpty);
    expect(model.childrenHasMore, isFalse);
    expect(model.tableRowsHasMore, isFalse);
  });

  test('response after disposal does not notify listeners', () async {
    final pending = Completer<dynamic>();
    final model = WikiReadModel(WikiRepository((_) => pending.future));
    var notifications = 0;
    model.addListener(() => notifications++);
    final request = model.refresh();
    model.dispose();
    pending.complete({'success': true, 'pages': [], 'next_offset': null});
    await request;
    expect(notifications, 1);
  });

  test('failed refresh retries from zero even after reaching final page',
      () async {
    var requests = 0;
    final offsets = <int>[];
    final model = WikiReadModel(
      WikiRepository((body) async {
        offsets.add(body['offset'] as int);
        if (++requests == 2) throw StateError('offline');
        return {
          'success': true,
          'pages': [
            {'id': 'a'},
          ],
          'next_offset': null,
        };
      }),
    );
    addTearDown(model.dispose);
    await model.refresh();
    await model.refresh();
    expect(model.pages.single['id'], 'a');
    expect(model.error, isNotNull);
    await model.retry();
    expect(model.error, isNull);
    expect(offsets, [0, 0, 0]);
  });

  test('failed detail can be retried without losing list navigation', () async {
    var requests = 0;
    final model = WikiReadModel(
      WikiRepository((_) async {
        if (++requests == 1) throw StateError('offline');
        return {
          'success': true,
          'page': {'id': 'a'},
        };
      }),
    );
    addTearDown(model.dispose);
    await model.select('a');
    expect(model.detailError, isNotNull);
    expect(model.error, isNull);
    await model.select(model.selectedId!);
    expect(model.detailError, isNull);
    expect(model.selectedPage!['id'], 'a');
  });
}
