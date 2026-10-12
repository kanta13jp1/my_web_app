import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/data/services/reading_book_search.dart';

void main() {
  test('author context preserves shared catalog editions whose label omits the author', () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    final books = await const ReadingBookSearch().search('エティカ', author: 'スピノザ', client: client);
    expect(books.any((book) => book.edition.translator == '工藤喜作・斎藤博'), isTrue);
  });
  test('Spinoza political treatise has a sourced Iwanami edition offline', () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    for (final query in ['国家論', '4-00-336156-3', '9784003361566']) {
      final books = await const ReadingBookSearch().search(query, client: client, author: 'スピノザ');
      expect(books, hasLength(1));
      final edition = books.single.edition;
      expect(edition.publisher, '岩波書店');
      expect(edition.translator, '畠中尚志');
      expect(edition.totalPages, 213);
      expect(edition.year, '1995');
      expect(edition.isbn, '9784003361566');
      expect(edition.editor, isEmpty);
      expect(edition.sourceUrl, 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002440109');
      expect(Uri.parse(edition.bookUrl).queryParameters['k'], edition.isbn);
    }
  });
  test('title lookup constrains NDL by the known author and does not match another author locally', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['title'], '国家論');
      expect(request.url.queryParameters['creator'], '別の著者');
      return http.Response('<rss><channel/></rss>', 200);
    });
    expect(await const ReadingBookSearch().search('国家論', author: '別の著者', client: client), isEmpty);
    expect(calls, 1);
  });
  test('explicit external Spinoza search sends title and creator separately', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['title'], '国家論');
      expect(request.url.queryParameters['creator'], 'スピノザ');
      return http.Response('<rss><channel/></rss>', 200);
    });
    expect(await const ReadingBookSearch().search('国家論', author: 'スピノザ', client: client, external: true), isEmpty);
  });

  test('RSS responsibility credits supplement authority-only creator entries',
      () async {
    final xml = ndlBooksFixture.replaceAll(
      '<dc:creator>訳者A 訳</dc:creator>',
      '<dc:creator>山田, 太郎, 1950-</dc:creator><author>山田, 太郎, 1950-,山田太郎 訳</author>',
    );
    final client =
        MockClient((_) async => http.Response.bytes(utf8.encode(xml), 200));
    final books =
        await const ReadingBookSearch().search('外部書名', client: client);
    expect(books.first.edition.translator, '山田太郎');
  });

  test(
      'external title search returns distinct sourced editions and role credits',
      () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'ndlsearch.ndl.go.jp');
      expect(request.url.queryParameters['title'], '目録にない外部書名');
      expect(request.url.queryParameters['dpid'], 'iss-ndl-opac');
      return http.Response.bytes(utf8.encode(ndlBooksFixture), 200);
    });
    final books = await const ReadingBookSearch().search(
      '目録にない外部書名',
      client: client,
    );
    expect(books, hasLength(2));
    expect(books[0].edition.publisher, '外部出版社A');
    expect(books[0].edition.translator, '訳者A');
    expect(books[0].edition.editor, '編者A');
    expect(books[0].edition.totalPages, 180);
    expect(books[0].edition.year, '2012');
    expect(books[0].edition.language, '日本語');
    expect(books[0].edition.isbn, '9784569804873');
    expect(books[1].edition.isbn, '9784569707839');
    expect(books[1].edition.translator, '訳者B');
    expect(books[1].edition.editor, '');
    expect(books[1].edition.totalPages, 240);
    expect(
      books[1].edition.sourceUrl,
      'https://ndlsearch.ndl.go.jp/books/R100000002-IQA002',
    );
    expect(
      Uri.parse(books[1].edition.bookUrl).queryParameters['k'],
      '9784569707839',
    );
  });
  test(
      'explicit external lookup can bypass local matches; malformed input fails',
      () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('<rss><channel/></rss>', 200);
    });
    expect(
      await const ReadingBookSearch().search(
        'エティカ',
        client: client,
        external: true,
      ),
      isEmpty,
    );
    expect(requests, 1);
    expect(
      await const ReadingBookSearch().search(
        '9781234567890',
        client: client,
      ),
      isEmpty,
    );
    expect(requests, 1);
    final wrong = MockClient((_) async => http.Response('<html/>', 200));
    await expectLater(
      const ReadingBookSearch().search('外部書名', client: wrong),
      throwsFormatException,
    );
  });
  test('unsafe provenance, unknown roles and complex extent are not guessed',
      () async {
    final xml = ndlBooksFixture
        .replaceAll('180p', 'iv, 180p')
        .replaceAll('訳者A 訳', '著者A 著')
        .replaceAll(
          'https://ndlsearch.ndl.go.jp/books/R100000002-IQA002',
          'https://example.invalid/book',
        );
    final client =
        MockClient((_) async => http.Response.bytes(utf8.encode(xml), 200));
    final books =
        await const ReadingBookSearch().search('外部書名', client: client);
    expect(books, hasLength(1));
    expect(books.single.edition.totalPages, isNull);
    expect(books.single.edition.translator, '');
    final unavailable = MockClient((_) async => http.Response('', 503));
    await expectLater(
      const ReadingBookSearch().search('外部書名', client: unavailable),
      throwsFormatException,
    );
  });

  test('personal reading title has a sourced edition without provider access',
      () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    final byTitle = await const ReadingBookSearch().search(
      '読書について',
      client: client,
    );
    final byIsbn = await const ReadingBookSearch().search(
      '978-4-334-75271-2',
      client: client,
    );
    expect(byTitle, hasLength(2));
    expect(byTitle.last.edition.isbn, '9784003363225');
    expect(byTitle.last.edition.translator, '斎藤忍随');
    expect(byTitle.last.edition.totalPages, 160);
    expect(
      byTitle.last.edition.sourceUrl,
      'https://www.hanmoto.com/bd/isbn/9784003363225',
    );
    expect(byTitle.first.edition.isbn, byIsbn.single.edition.isbn);
    expect(byTitle.first.edition.publisher, '光文社');
    expect(byTitle.first.edition.translator, '鈴木芳子');
    expect(byTitle.first.edition.editor, '');
    expect(byTitle.first.edition.totalPages, isNull);
    expect(
      byTitle.first.edition.sourceUrl,
      'https://www.kotensinyaku.jp/books/book169/',
    );
  });
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

const ndlBooksFixture =
    r'''<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcndl="http://ndl.go.jp/dcndl/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><channel>
<item><dc:title>目録にない外部書名</dc:title><link>https://ndlsearch.ndl.go.jp/books/R100000002-IQA001</link><dc:publisher>外部出版社A</dc:publisher><dc:creator>原著者 著</dc:creator><dc:creator>訳者A 訳</dc:creator><dc:creator>編者A 編</dc:creator><dc:extent>180p</dc:extent><dcterms:issued>2012.3</dcterms:issued><dc:language>jpn</dc:language><dc:identifier xsi:type="dcndl:ISBN">978-4-569-80487-3</dc:identifier></item>
<item><dc:title>目録にない外部書名</dc:title><link>https://ndlsearch.ndl.go.jp/books/R100000002-IQA002</link><dc:publisher>外部出版社B</dc:publisher><dc:creator>訳者B 訳</dc:creator><dc:extent>240 p</dc:extent><dcterms:issued>2009.8</dcterms:issued><dc:identifier xsi:type="dcndl:ISBN">978-4-569-70783-9</dc:identifier></item>
</channel></rss>''';
