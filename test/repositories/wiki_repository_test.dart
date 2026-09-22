import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/repositories/wiki_repository.dart';

void main() {
  test('list sends bounded pagination and normalizes hub pages', () async {
    final repository = WikiRepository((body) async {
      expect(body, {'action': 'wiki.list', 'offset': 50, 'limit': 1});
      return {
        'success': true,
        'pages': [
          {'id': 'real', 'metadata': {'id': 'old', 'title': 'Title'}},
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
    final repository = WikiRepository((_) async => {
          'success': true,
          'pages': <dynamic>[],
          'next_offset': null,
        },);
    final batch = await repository.list();
    expect(batch.pages, isEmpty);
    expect(batch.nextOffset, isNull);
  });

  test('invalid continuation is rejected rather than looping or truncating', () async {
    for (final next in [0, -1, '50', 51]) {
      final repository = WikiRepository((_) async => {
            'success': true,
            'pages': <dynamic>[],
            'next_offset': next,
          },);
      await expectLater(repository.list(), throwsFormatException);
    }
    final legacy = WikiRepository((_) async => {
          'success': true,
          'pages': <dynamic>[],
        },);
    await expectLater(legacy.list(), throwsFormatException);
  });

  test('get requests exact ID and preserves multiline content', () async {
    final repository = WikiRepository((body) async {
      expect(body, {'action': 'wiki.get', 'id': 'page-75'});
      return {
        'success': true,
        'page': {'id': 'page-75', 'metadata': {'content': 'a\n\n b'}},
      };
    });
    expect((await repository.get('page-75'))['content'], 'a\n\n b');
  });

  test('get rejects wrong page identity and unsuccessful responses', () async {
    final wrong = WikiRepository((_) async => {
          'success': true,
          'page': {'id': 'other'},
        },);
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
