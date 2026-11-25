import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/repositories/wiki_repository.dart';

void main() {
  test('list sends bounded pagination and normalizes hub pages', () async {
    final repository = WikiRepository((body) async {
      expect(body, {'action': 'wiki.list', 'offset': 50, 'limit': 1});
      return {
        'success': true,
        'pages': [
          {
            'id': 'real',
            'metadata': {'id': 'old', 'title': 'Title'},
          },
        ],
        'next_offset': 51,
      };
    });
    final batch = await repository.list(offset: 50, limit: 1);
    expect(batch.nextOffset, 51);
    expect(batch.pages.single['id'], 'real');
    expect(batch.pages.single['title'], 'Title');
    expect(() => batch.pages.clear(), throwsUnsupportedError);
    expect(() => batch.pages.single['title'] = 'edit', throwsUnsupportedError);
  });

  test('empty final page is distinct from malformed response', () async {
    final repository = WikiRepository(
      (_) async => {
        'success': true,
        'pages': <dynamic>[],
        'next_offset': null,
      },
    );
    final batch = await repository.list();
    expect(batch.pages, isEmpty);
    expect(batch.nextOffset, isNull);
  });

  test('invalid continuation is rejected rather than looping or truncating',
      () async {
    for (final next in [0, -1, '50', 51]) {
      final repository = WikiRepository(
        (_) async => {
          'success': true,
          'pages': <dynamic>[],
          'next_offset': next,
        },
      );
      await expectLater(repository.list(), throwsFormatException);
    }
    final legacy = WikiRepository(
      (_) async => {
        'success': true,
        'pages': <dynamic>[],
      },
    );
    await expectLater(legacy.list(), throwsFormatException);
  });

  test('get requests exact ID and preserves multiline content', () async {
    final repository = WikiRepository((body) async {
      expect(body, {'action': 'wiki.get', 'id': 'page-75'});
      return {
        'success': true,
        'page': {
          'id': 'page-75',
          'metadata': {'content': 'a\n\n b'},
        },
      };
    });
    expect((await repository.get('page-75'))['content'], 'a\n\n b');
  });

  test('getDetail normalizes children, table rows, and truncation flags',
      () async {
    final repository = WikiRepository((body) async {
      expect(body, {'action': 'wiki.get', 'id': 'root-1'});
      return {
        'success': true,
        'page': {
          'id': 'root-1',
          'metadata': {'title': 'Root', 'content': 'Body'},
        },
        'children': [
          {
            'id': 'sub-1',
            'metadata': {'title': 'Subpage 1', 'parent_id': 'root-1'},
          },
        ],
        'children_has_more': true,
        'table_rows': [
          {
            'id': 'row-1',
            'created_at': '2026-11-25T00:00:00Z',
            'metadata': {
              'sheet_id': 'root-1',
              'data': {'content': 'Row payload'},
            },
          },
        ],
        'table_rows_has_more': true,
      };
    });
    final detail = await repository.getDetail('root-1');
    expect(detail.page['title'], 'Root');
    expect(detail.children.single['id'], 'sub-1');
    expect(detail.children.single['title'], 'Subpage 1');
    expect(detail.childrenHasMore, isTrue);
    expect(detail.tableRows.single['content'], 'Row payload');
    expect(detail.tableRows.single['createdAt'], '2026-11-25T00:00:00Z');
    expect(detail.tableRowsHasMore, isTrue);
    expect(() => detail.children.clear(), throwsUnsupportedError);
    expect(() => detail.tableRows.clear(), throwsUnsupportedError);
  });

  test('getDetail rejects malformed detail lists and flags', () async {
    final badChildren = WikiRepository(
      (_) async => {
        'success': true,
        'page': {'id': 'p1'},
        'children': 'not-a-list',
      },
    );
    await expectLater(badChildren.getDetail('p1'), throwsFormatException);
    final badFlag = WikiRepository(
      (_) async => {
        'success': true,
        'page': {'id': 'p1'},
        'children_has_more': 'yes',
      },
    );
    await expectLater(badFlag.getDetail('p1'), throwsFormatException);
  });

  test('createPage sends parent_id and validates non-empty title', () async {
    final requests = <Map<String, dynamic>>[];
    final repository = WikiRepository((body) async {
      requests.add(body);
      return {
        'success': true,
        'page': {
          'id': 'child-9',
          'metadata': {'title': 'Child', 'parent_id': 'root-1'},
        },
      };
    });
    await expectLater(
      repository.createPage(title: '   ', content: 'Body'),
      throwsArgumentError,
    );
    await expectLater(
      repository.createPage(title: 'Title', content: 'Body', parentId: ' '),
      throwsArgumentError,
    );
    final created = await repository.createPage(
      title: ' Child ',
      content: ' Body ',
      parentId: ' root-1 ',
    );
    expect(created['id'], 'child-9');
    expect(requests.single, {
      'action': 'wiki.create',
      'title': 'Child',
      'content': 'Body',
      'parent_id': 'root-1',
    });
  });

  test('addTableRow posts sheet.add_row and normalizes returned row', () async {
    final requests = <Map<String, dynamic>>[];
    final repository = WikiRepository((body) async {
      requests.add(body);
      return {
        'success': true,
        'row': {
          'id': 'row-5',
          'metadata': {
            'sheet_id': 'root-1',
            'data': {'content': 'Alpha'},
          },
        },
      };
    });
    await expectLater(
      repository.addTableRow(pageId: '  ', content: 'Alpha'),
      throwsArgumentError,
    );
    final row = await repository.addTableRow(
      pageId: 'root-1',
      content: ' Alpha ',
    );
    expect(row['content'], 'Alpha');
    expect(requests.single, {
      'action': 'sheet.add_row',
      'sheet_id': 'root-1',
      'data': {'content': 'Alpha'},
    });
  });

  test('get rejects wrong page identity and unsuccessful responses', () async {
    final wrong = WikiRepository(
      (_) async => {
        'success': true,
        'page': {'id': 'other'},
      },
    );
    await expectLater(wrong.get('expected'), throwsFormatException);
    final failed = WikiRepository((_) async => {'success': false});
    await expectLater(failed.list(), throwsFormatException);
  });

  test('transport failure propagates and retry invokes API again', () async {
    var attempts = 0;
    final repository = WikiRepository((_) async {
      if (++attempts == 1) throw StateError('offline');
      return {'success': true, 'pages': <dynamic>[], 'next_offset': null};
    });
    await expectLater(repository.list(), throwsStateError);
    expect((await repository.list()).pages, isEmpty);
    expect(attempts, 2);
  });

  test('invalid local pagination makes no network call', () async {
    final repository = WikiRepository((_) async => fail('Unexpected request'));
    await expectLater(repository.list(offset: -1), throwsArgumentError);
    await expectLater(repository.list(limit: 101), throwsArgumentError);
    await expectLater(repository.get('  '), throwsArgumentError);
  });
}
