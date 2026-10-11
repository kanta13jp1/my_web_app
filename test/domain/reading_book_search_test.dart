import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/data/services/reading_book_search.dart';

void main() {
  test(
    'ISBN-10 normalizes to ISBN-13; bad checksums never query the provider',
    () async {
      final client = MockClient(
        (_) => throw StateError('Network must not be used'),
      );
      final books = await const ReadingBookSearch().search(
        '4-00-332021-2',
        client: client,
      );
      expect(books.single.edition.isbn, '9784003320211');
      expect(
        await const ReadingBookSearch().search('9781234567890', client: client),
        isEmpty,
      );
    },
  );
  test(
      'catalog title and ISBN return verified editions without a network request',
      () async {
    final client =
        MockClient((_) => throw StateError('Network must not be used'));
    final books =
        await const ReadingBookSearch().search('エティカ', client: client);
    expect(books.any((book) => book.edition.translator == '工藤喜作・斎藤博'), isTrue);
    final exact = await const ReadingBookSearch()
        .search('978-4121600943', client: client);
    expect(exact.single.edition.publisher, '中央公論新社');
  });
  test('ISBN lookup preserves explicit contributor roles, pages and provenance',
      () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['isbn'], '9781234567897');
      return http.Response(
        jsonEncode([
          {
            'summary': {
              'isbn': '9781234567897',
              'title': '検索した本',
              'publisher': '出版社',
              'pubdate': '202610',
            },
            'onix': {
              'DescriptiveDetail': {
                'Contributor': [
                  {
                    'ContributorRole': ['A01'],
                    'PersonName': {'content': '著者'},
                  },
                  {
                    'ContributorRole': ['B06'],
                    'PersonName': {'content': '訳者'},
                  },
                  {
                    'ContributorRole': ['B01'],
                    'PersonName': {'content': '編者'},
                  },
                ],
                'Extent': [
                  {'ExtentUnit': '03', 'ExtentValue': '240'},
                ],
              },
            },
          }
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final result = (await const ReadingBookSearch()
            .search('9781234567897', client: client))
        .single;
    expect(result.title, '検索した本');
    expect(result.edition.translator, '訳者');
    expect(result.edition.editor, '編者');
    expect(result.edition.totalPages, 240);
    expect(result.edition.year, '2026');
    expect(result.edition.language, isEmpty);
    expect(result.edition.sourceUrl, contains('openbd.jp'));
    expect(
      Uri.parse(result.edition.bookUrl).queryParameters['k'],
      '9781234567897',
    );
  });
  test('missing and mismatched ISBN do not invent book information', () async {
    for (final payload in [
      '[null]',
      '[{"summary":{"isbn":"9781234567890"}}]',
    ]) {
      final client = MockClient((_) async => http.Response(payload, 200));
      expect(
        await const ReadingBookSearch().search('9781234567897', client: client),
        isEmpty,
      );
    }
  });
  test('unavailable service reports failure rather than an empty success',
      () async {
    final client = MockClient((_) async => http.Response('', 503));
    expect(
      const ReadingBookSearch().search('9781234567897', client: client),
      throwsFormatException,
    );
  });
}
