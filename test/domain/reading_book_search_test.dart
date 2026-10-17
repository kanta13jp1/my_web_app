import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/data/services/reading_book_search.dart';
import 'package:my_web_app/data/catalogs/philosophy_catalog.dart';

void main() {
  final iwanamiCases = (jsonDecode(
              r'''[{"work":"plato:apology","title":"ソクラテスの弁明・クリトン","isbn":"9784003360118","translator":"久保勉","year":"1964","pages":118,"volume":"岩波文庫 青601-1","editor":"","note":"「ソクラテスの弁明」と「クリトン」の合本。118ページは合本全体の値です。","source":"https://www.hanmoto.com/bd/isbn/9784003360118"},{"work":"aristotle:nicomachean-ethics","title":"ニコマコス倫理学（上）","isbn":"9784003360415","translator":"高田三郎","year":"1971","pages":294,"volume":"岩波文庫 青604-1・上巻","editor":"","note":"上下二巻のうち上巻。ページ数は出版社提供書誌のこの巻の値です。改版・刷による差は手元の本で確認してください。","source":"https://www.hanmoto.com/bd/isbn/9784003360415"},{"work":"aristotle:nicomachean-ethics","title":"ニコマコス倫理学（下）","isbn":"9784003360422","translator":"高田三郎","year":"1973","pages":302,"volume":"岩波文庫 青604-2・下巻","editor":"","note":"上下二巻のうち下巻。ページ数は出版社提供書誌のこの巻の値です。改版・刷による差は手元の本で確認してください。","source":"https://www.hanmoto.com/bd/isbn/9784003360422"},{"work":"descartes:discourse","title":"方法序説","isbn":"9784003361313","translator":"谷川多佳子","year":"1997","pages":160,"volume":"岩波文庫 青613-1","editor":"","note":"","source":"https://www.hanmoto.com/bd/isbn/9784003361313"},{"work":"descartes:meditations","title":"省察","isbn":"9784003361320","translator":"三木清","year":"1949","pages":167,"volume":"岩波文庫 青613-2","editor":"","note":"東京都立大学図書館書誌の1949年刊・167ページ。手元の刷の発行年は別途確認してください。","source":"https://opactmu.lib.tmu.ac.jp/iwjs0013opc/catdbl.do?hidden_return_link=true&pkey=BB00123729"},{"work":"rousseau:social-contract","title":"社会契約論","isbn":"9784003362334","translator":"桑原武夫・前川貞次郎","year":"1954","pages":246,"volume":"岩波文庫 青623-3","editor":"","note":"","source":"https://www.hanmoto.com/bd/isbn/9784003362334"},{"work":"mill:liberty","title":"自由論","isbn":"9784003900024","translator":"関口正司","year":"2020","pages":302,"volume":"岩波文庫・関口正司訳","editor":"","note":"","source":"https://www.hanmoto.com/bd/isbn/9784003900024"},{"work":"marcus-aurelius:meditations","title":"自省録","isbn":"9784003361016","translator":"神谷美恵子","year":"2007","pages":null,"volume":"岩波文庫 青610-1・改版","editor":"","note":"同じISBNのページ数に書誌間の差があるため未設定です。手元の本の総ページ数を登録してください。出版年は改版の書誌年です。","source":"https://www.hanmoto.com/bd/isbn/9784003361016"},{"work":"marx:manifesto","title":"共産党宣言","isbn":"9784003412459","translator":"大内兵衛・向坂逸郎","year":"1971","pages":116,"volume":"岩波文庫 白124-5・改訳","editor":"","note":"マルクスとエンゲルスの共著。訳者2名は国立情報学研究所CiNii Booksの改訳書誌でも確認。","source":"https://www.hanmoto.com/bd/isbn/9784003412459"},{"work":"zhuangzi:zhuangzi","title":"荘子 第1冊","isbn":"9784003320617","translator":"金谷治（訳注）","year":"1971","pages":268,"volume":"岩波文庫 青206-1・第1冊","editor":"","note":"全四冊のうち第1冊。ページ数はこの冊のみの値です。金谷治の役割は訳注（図書館書誌で確認）。","source":"https://www.hanmoto.com/bd/isbn/9784003320617"},{"work":"zhuangzi:zhuangzi","title":"荘子 第2冊","isbn":"9784003320624","translator":"金谷治（訳注）","year":"1975","pages":284,"volume":"岩波文庫 青206-2・第2冊","editor":"","note":"全四冊のうち第2冊。ページ数はこの冊のみの値です。金谷治の役割は訳注（図書館書誌で確認）。","source":"https://www.hanmoto.com/bd/isbn/9784003320624"},{"work":"zhuangzi:zhuangzi","title":"荘子 第3冊","isbn":"9784003320631","translator":"金谷治（訳注）","year":"1982","pages":334,"volume":"岩波文庫 青206-3・第3冊","editor":"","note":"全四冊のうち第3冊。ページ数はこの冊のみの値です。金谷治の役割は訳注（図書館書誌で確認）。","source":"https://www.hanmoto.com/bd/isbn/9784003320631"},{"work":"zhuangzi:zhuangzi","title":"荘子 第4冊","isbn":"9784003320648","translator":"金谷治（訳注）","year":"1983","pages":330,"volume":"岩波文庫 青206-4・第4冊","editor":"","note":"全四冊のうち第4冊。ページ数はこの冊のみの値です。金谷治の役割は訳注（図書館書誌で確認）。","source":"https://www.hanmoto.com/bd/isbn/9784003320648"},{"work":"wang-yangming:instructions","title":"伝習録","isbn":"9784003321218","translator":"山田準・鈴木直治（訳註）","year":"1936","pages":493,"volume":"岩波文庫 青212-1","editor":"","note":"出版年は出版社提供書誌の昭和11年（1936年）。手元の刷の発行年は別途確認してください。","source":"https://www.hanmoto.com/bd/isbn/9784003321218"},{"work":"dogen:zuimonki","title":"正法眼蔵随聞記","isbn":"9784003331941","translator":"","year":"1982","pages":176,"volume":"岩波文庫 青319-4・改版","editor":"懐奘（編）・和辻哲郎（校訂）","note":"現代語訳とは区別し、編者・校訂者を編集者欄に記録。役割は大学図書館書誌で確認。","source":"https://www.hanmoto.com/bd/isbn/9784003331941"}]''',)
          as List)
      .cast<Map<String, dynamic>>();
  for (final expected in iwanamiCases) {
    test('verified Iwanami title and ISBN search: ${expected['isbn']}',
        () async {
      final work =
          philosophyWorks.singleWhere((work) => work.id == expected['work']);
      final client = MockClient(
        (_) => throw StateError('Catalog must work offline'),
      );
      final isbn = expected['isbn'] as String;
      final body = isbn.substring(3, 12);
      final sum = List.generate(
        9,
        (i) => int.parse(body[i]) * (10 - i),
      ).reduce((a, b) => a + b);
      final check = (11 - sum % 11) % 11;
      final isbn10 = '$body${check == 10 ? 'X' : check}';
      for (final query in [
        work.title,
        isbn,
        isbn10,
      ]) {
        final matches = await const ReadingBookSearch().search(
          query,
          author: work.author.name,
          client: client,
        );
        final edition =
            matches.singleWhere((book) => book.edition.isbn == isbn).edition;
        expect(edition.publisher, '岩波書店');
        expect(edition.translator, expected['translator']);
        expect(edition.editor, expected['editor']);
        expect(edition.totalPages, expected['pages']);
        expect(edition.year, expected['year']);
        expect(edition.volume, expected['volume']);
        expect(edition.sourceUrl, expected['source']);
        expect(
          edition.bookUrl,
          'https://www.amazon.co.jp/s/?i=stripbooks&k=$isbn',
        );
      }
    });
  }

  test('Aristotle Metaphysics has separate sourced Iwanami volumes offline',
      () async {
    final client = MockClient(
      (_) => throw StateError('No external search needed'),
    );
    final books = await const ReadingBookSearch().search(
      '形而上学',
      author: 'アリストテレス',
      client: client,
    );
    expect(books.any((book) => book.edition.isbn == '9784061591165'), isTrue);
    for (final (isbn, pages, year, source) in [
      (
        '9784003360439',
        420,
        '1959',
        'https://www.hanmoto.com/bd/isbn/9784003360439',
      ),
      (
        '9784003360446',
        458,
        '1961',
        'https://www.books.or.jp/book-details/9784003360446',
      ),
    ]) {
      final edition =
          books.singleWhere((book) => book.edition.isbn == isbn).edition;
      expect(edition.publisher, '岩波書店');
      expect(edition.translator, '出隆');
      expect(edition.editor, isEmpty);
      expect(edition.totalPages, pages);
      expect(edition.year, year);
      expect(edition.sourceUrl, source);
      expect(
        edition.bookUrl,
        'https://www.amazon.co.jp/s/?i=stripbooks&k=$isbn',
      );
      for (final query in [
        isbn,
        isbn == '9784003360439' ? '4003360435' : '4003360443',
      ]) {
        final matches = await const ReadingBookSearch().search(
          query,
          client: client,
        );
        expect(matches.any((book) => book.edition.isbn == isbn), isTrue);
      }
    }
  });

  const unconfirmed = {'averroes:decisive-treatise', 'butler:afraid-gender'};
  for (final work
      in philosophyWorks.where((work) => !unconfirmed.contains(work.id))) {
    test('catalog automatic title finds sourced Japanese editions: ${work.id}',
        () async {
      final client = MockClient(
        (_) => throw StateError('Curated editions must be available offline'),
      );
      final books = await const ReadingBookSearch()
          .search(work.title, author: work.author.name, client: client);
      expect(
        books,
        isNotEmpty,
        reason: work.title,
      );
      for (final book in books) {
        expect(
          book.workId,
          work.id,
        );
        expect(
          book.edition.language,
          '日本語',
        );
        expect(
          book.edition.publisher,
          isNotEmpty,
        );
        expect(
          Uri.parse(book.edition.sourceUrl).scheme,
          'https',
        );
        expect(
          Uri.parse(book.edition.bookUrl).scheme,
          'https',
        );
      }
    });
  }
  test(
      'only the two explicitly unconfirmed works lack curated Japanese editions',
      () {
    expect(
      philosophyWorks
          .where(
            (work) => !philosophyCatalogEditions
                .any((book) => book.workId == work.id),
          )
          .map((work) => work.id)
          .toSet(),
      unconfirmed,
    );
  });
  test('a different author does not borrow editions through a catalog title',
      () async {
    final client = MockClient((request) async {
      expect(
        request.url.queryParameters['creator'],
        '別の著者',
      );
      return http.Response('<rss><channel/></rss>', 200);
    });
    expect(
      await const ReadingBookSearch()
          .search('道徳経', author: '別の著者', client: client),
      isEmpty,
    );
    expect(
      await const ReadingBookSearch()
          .search('読書について', author: '別の著者', client: client),
      isEmpty,
    );
    expect(
      await const ReadingBookSearch().search('!!!', client: client),
      isEmpty,
    );
  });
  test(
      'Japanese alternate title, author alias and anthology notes are preserved',
      () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    final ethics = await const ReadingBookSearch()
        .search('エチカ', author: 'Spinoza', client: client);
    expect(
      ethics.map((book) => book.edition.isbn),
      containsAll(['9784121600943', '9784003361542', '9784003361559']),
    );
    final ideas = await const ReadingBookSearch()
        .search('イデーンⅠ', author: 'フッサール', client: client);
    expect(
      ideas,
      hasLength(2),
    );
    expect(
      ideas.every((book) => book.note.isNotEmpty),
      isTrue,
    );
    final farabi = (await const ReadingBookSearch()
            .search('有徳都市の住民の見解', author: 'ファーラービー', client: client))
        .single;
    expect(
      farabi.edition.translator,
      '竹下政孝',
    );
    expect(
      farabi.edition.isbn,
      '9784582734218',
    );
    expect(
      farabi.edition.totalPages,
      1161,
    );
    expect(
      farabi.note,
      contains('巻全体'),
    );
  });
  test(
      'catalog ISBN-10 resolves without asking openBD and all catalog ISBNs resolve locally',
      () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    final oldButler =
        await const ReadingBookSearch().search('4791757033', client: client);
    expect(
      oldButler.single.edition.isbn,
      '4791757033',
    );
    expect(
      (await const ReadingBookSearch().search('9784791757039', client: client))
          .single
          .edition
          .isbn,
      '4791757033',
    );
    for (final book in philosophyCatalogEditions
        .where((book) => book.edition.isbn.isNotEmpty)) {
      final results = await const ReadingBookSearch()
          .search(book.edition.isbn, client: client);
      expect(
        results.any(
          (result) => result.edition.sourceUrl == book.edition.sourceUrl,
        ),
        isTrue,
        reason: book.label,
      );
    }
  });
  test(
      'author context preserves shared catalog editions whose label omits the author',
      () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    final books = await const ReadingBookSearch()
        .search('エティカ', author: 'スピノザ', client: client);
    expect(books.any((book) => book.edition.translator == '工藤喜作・斎藤博'), isTrue);
  });
  test('Spinoza political treatise has a sourced Iwanami edition offline',
      () async {
    final client = MockClient((_) => throw StateError('No provider request'));
    for (final query in ['国家論', '4-00-336156-3', '9784003361566']) {
      final books = await const ReadingBookSearch()
          .search(query, client: client, author: 'スピノザ');
      expect(books, hasLength(1));
      final edition = books.single.edition;
      expect(edition.publisher, '岩波書店');
      expect(edition.translator, '畠中尚志');
      expect(edition.totalPages, 213);
      expect(edition.year, '1995');
      expect(edition.isbn, '9784003361566');
      expect(edition.editor, isEmpty);
      expect(
        edition.sourceUrl,
        'https://ndlsearch.ndl.go.jp/books/R100000002-I000002440109',
      );
      expect(Uri.parse(edition.bookUrl).queryParameters['k'], edition.isbn);
    }
  });
  test(
      'title lookup constrains NDL by the known author and does not match another author locally',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['title'], '国家論');
      expect(request.url.queryParameters['creator'], '別の著者');
      return http.Response('<rss><channel/></rss>', 200);
    });
    expect(
      await const ReadingBookSearch()
          .search('国家論', author: '別の著者', client: client),
      isEmpty,
    );
    expect(calls, 1);
  });
  test('explicit external Spinoza search sends title and creator separately',
      () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['title'], '国家論');
      expect(request.url.queryParameters['creator'], 'スピノザ');
      return http.Response('<rss><channel/></rss>', 200);
    });
    expect(
      await const ReadingBookSearch()
          .search('国家論', author: 'スピノザ', client: client, external: true),
      isEmpty,
    );
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
