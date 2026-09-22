import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/repositories/wiki_repository.dart';
import 'package:my_web_app/view_models/wiki_read_model.dart';

void main() {
  test('append failure preserves pages and retries the same offset', () async {
    var failNext = true;
    final offsets = <int>[];
    final model = WikiReadModel(WikiRepository((body) async {
      offsets.add(body['offset'] as int);
      if (body['offset'] == 0) {
        return {
          'success': true,
          'pages': List.generate(50, (n) => {'id': 'p-$n'}),
          'next_offset': 50,
        };
      }
      if (failNext) { failNext = false; throw StateError('offline'); }
      return {'success': true, 'pages': [{'id': 'p-50'}], 'next_offset': null};
    }));
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
    final model = WikiReadModel(WikiRepository((body) => body['id'] == 'a' ? a.future : b.future));
    addTearDown(model.dispose);
    final first = model.select('a');
    final second = model.select('b');
    b.complete({'success': true, 'page': {'id': 'b'}});
    await second;
    a.complete({'success': true, 'page': {'id': 'a'}});
    await first;
    expect(model.selectedId, 'b');
    expect(model.selectedPage!['id'], 'b');
    expect(model.detailLoading, isFalse);
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
}
