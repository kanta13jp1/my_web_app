import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/catalogs/philosophy_catalog.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';

void main() {
  test('catalog identity, sources and BCE compound classification', () {
    expect(philosophyAuthors.length, 56);
    expect(philosophyWorks.length, 80);
    expect(philosophyWorks.map((w) => w.id).toSet().length, 80);
    expect(
      philosophyWorks.every((w) => w.source.startsWith('https://')),
      isTrue,
    );
    final matches = philosophyWorks.where(
      const ReadingFilter(
        query: 'Plato',
        century: '紀元前4世紀',
        region: '古代ギリシア',
        genre: '政治哲学',
      ).matches,
    );
    expect(matches.map((w) => w.title), ['国家']);
    expect(
      philosophyWorks.where(const ReadingFilter(century: '不明').matches),
      isNotEmpty,
    );
  });
  test(
      'coverage unions ranges, while pages retain rereading and unspecified counts',
      () {
    const cycle = ReadingCycle(
      id: 'c',
      startedAt: '2026-10-11',
      edition: ReadingEdition(totalPages: 100),
      entries: [
        ReadingEntry(
          id: 'a',
          date: '2026-10-11',
          pages: 10,
          startPage: 1,
          endPage: 10,
        ),
        ReadingEntry(
          id: 'b',
          date: '2026-10-11',
          pages: 11,
          startPage: 5,
          endPage: 15,
        ),
        ReadingEntry(id: 'c', date: '2026-10-11', pages: 20),
      ],
    );
    expect(cycle.coveredPages, 15);
    expect(cycle.pagesRead, 41);
    expect(cycle.coverage, .15);
    const unknown = ReadingCycle(id: 'd', startedAt: '2026-10-11');
    expect(unknown.coverage, isNull);
  });
  test('bad dates, out-of-edition ranges and understanding are rejected', () {
    expect(
      const ReadingEntry(id: 'a', date: '2026-02-30', pages: 0).validate(null),
      isNotNull,
    );
    expect(
      const ReadingEntry(
        id: 'a',
        date: '2026-10-11',
        pages: 11,
        startPage: 90,
        endPage: 100,
      ).validate(99),
      isNotNull,
    );
    expect(
      const ReadingEntry(
        id: 'a',
        date: '2026-10-11',
        pages: 0,
        understanding: 6,
      ).validate(null),
      isNotNull,
    );
    expect(
      const ReadingEntry(
        id: 'a',
        date: '2026-10-11',
        pages: 0,
        understanding: 1,
      ).validate(null),
      isNull,
    );
  });
  test(
      'completed works deduplicate rereading and editions; empty target is zero',
      () {
    final work = philosophyWorks.first;
    final records = [
      for (var i = 0; i < 2; i++)
        ReadingRecord(
          id: '$i',
          work: work,
          cycles: const [
            ReadingCycle(
              id: 'read',
              startedAt: '2026-10-11',
              finishedAt: '2026-10-11',
              status: 'read',
            ),
            ReadingCycle(
              id: 'reread',
              startedAt: '2026-10-11',
              status: 'reading',
            ),
          ],
        ),
    ];
    final progress = ReadingProgress(philosophyWorks, records);
    expect(progress.completed, 1);
    expect(progress.total, philosophyWorks.length);
    expect(ReadingProgress([], records).fraction, 0);
  });
  test(
      'legacy titles remain separate and a reopened new cycle is no longer complete',
      () {
    final old = ReadingRecord.fromHub({
      'id': 'old',
      'metadata': {'title': '旧本', 'author': 'カント', 'status': 'read'},
    });
    expect(old.work.id, 'legacy:old');
    expect(old.isRead, isTrue);
    final reopened = ReadingRecord.fromHub({
      'id': 'new',
      'metadata': {
        'work': philosophyWorks.first.toJson(),
        'status': 'unread',
        'reading_legacy_read': false,
        'cycles': [
          const ReadingCycle(id: 'c', startedAt: '2026-10-11').toJson(),
        ],
      },
    });
    expect(reopened.isRead, isFalse);
  });
  test(
      'expanded catalog keeps identity, East/West coverage and edition attribution',
      () {
    final authors = {for (final author in philosophyAuthors) author.id: author};
    expect(authors.length, philosophyAuthors.length);
    final century = RegExp(r'^(紀元前)?[1-9][0-9]*世紀$');
    for (final work in philosophyWorks) {
      expect(authors[work.author.id]?.toJson(), work.author.toJson());
      expect(isReadingHttpsUrl(work.source), isTrue, reason: work.id);
      expect(isReadingHttpsUrl(work.author.source), isTrue, reason: work.id);
      expect(work.author.regions, isNotEmpty);
      expect(work.genres, isNotEmpty);
      expect(work.centuries, isNotEmpty);
      expect(
        work.centuries.every((c) => c == '不明' || century.hasMatch(c)),
        isTrue,
      );
      expect(
        work.author.centuries.every((c) => c == '不明' || century.hasMatch(c)),
        isTrue,
      );
      expect(
        readingBookSearchLinks(work)
            .values
            .every((url) => url.scheme == 'https'),
        isTrue,
      );
    }
    for (final id in [
      'confucius:analects',
      'plato:republic',
      'nagarjuna:mulamadhyamakakarika',
      'avicenna:healing',
      'dogen:shobogenzo',
      'aquinas:summa',
      'butler:afraid-gender',
      'sen:idea-justice',
    ]) {
      expect(philosophyWorks.any((w) => w.id == id), isTrue, reason: id);
    }
    expect(
      philosophyWorks
          .where(const ReadingFilter(century: '21世紀', genre: '政治哲学').matches),
      isNotEmpty,
    );
    for (final book in philosophyCatalogEditions) {
      expect(philosophyWorks.any((w) => w.id == book.workId), isTrue);
      expect(isReadingHttpsUrl(book.edition.sourceUrl), isTrue);
      expect(book.edition.publisher, isNotEmpty);
      expect(book.edition.isbn, matches(RegExp(r'^(\d{10}|\d{13})$')));
      expect(
        readingBookSearchLinks(
          philosophyWorks.first,
          book.edition,
        )['Amazonで書籍を検索']!
            .queryParameters['k'],
        book.edition.isbn,
      );
    }
    expect(
      philosophyCatalogEditions
          .singleWhere((b) => b.workId == 'dogen:zuimonki')
          .edition
          .editor,
      contains('懐奘'),
    );
  });
  test(
      'old editions default new fields; editor and book/source links round trip',
      () {
    final old =
        ReadingEdition.fromJson({'publisher': '旧出版社', 'total_pages': 100});
    expect(old.editor, isEmpty);
    expect(old.bookUrl, isEmpty);
    expect(old.sourceUrl, isEmpty);
    const edition = ReadingEdition(
      publisher: '出版社',
      translator: '訳者',
      editor: '編者',
      bookUrl: 'https://example.com/book',
      sourceUrl: 'https://example.com/bibliography',
    );
    expect(
      ReadingEdition.fromJson(edition.toJson()).toJson(),
      edition.toJson(),
    );
    for (final url in [
      'http://example.com',
      'javascript:alert(1)',
      'https://',
      'https://user:password@example.com',
    ]) {
      expect(isReadingHttpsUrl(url), isFalse);
    }
    const work = PhilosophyWork(
      id: 'a',
      title: '道 & 思想',
      author: PhilosophyAuthor(id: 'a', name: '著者'),
    );
    expect(
      readingBookSearchLinks(work)['Amazonで書籍を検索']!.queryParameters['k'],
      '道 & 思想 著者',
    );
  });

  test(
      'Japanese editions keep ISBN identity, source attribution and independent cycles',
      () {
    final ids = <String>{};
    for (final book in philosophyCatalogEditions) {
      final edition = book.edition;
      expect(ids.add('${book.workId}:${edition.isbn}'), isTrue);
      expect(edition.translator, isNotEmpty);
      expect(isReadingHttpsUrl(edition.bookUrl), isTrue);
      expect(
        ReadingEdition.fromJson(edition.toJson()).toJson(),
        edition.toJson(),
      );
      final digits = edition.isbn.split('').map((d) => int.parse(d)).toList();
      if (digits.length == 13) {
        final sum = List.generate(13, (i) => digits[i] * (i.isEven ? 1 : 3))
            .reduce((a, b) => a + b);
        expect(sum % 10, 0, reason: edition.isbn);
      } else {
        final sum = List.generate(10, (i) => digits[i] * (10 - i))
            .reduce((a, b) => a + b);
        expect(sum % 11, 0, reason: edition.isbn);
      }
    }
    expect(philosophyCatalogEditions.length, 33);
    expect(
      philosophyCatalogEditions
          .where((b) => b.edition.language == '日本語')
          .length,
      32,
    );
    final books = philosophyCatalogEditions
        .where((b) => b.workId == 'confucius:analects')
        .toList();
    expect(
      books.map((b) => b.edition.isbn).toSet(),
      {'9784003320211', '9784334107741'},
    );
    final record = ReadingRecord(
      id: 'editions',
      work: philosophyWorks.firstWhere((w) => w.id == 'confucius:analects'),
      cycles: [
        for (var i = 0; i < books.length; i++)
          ReadingCycle(
            id: 'cycle-$i',
            startedAt: '2026-10-11',
            edition: books[i].edition,
          ),
      ],
    );
    final restored = ReadingRecord.fromHub(
      {'id': record.id, 'metadata': record.savePayload()},
    );
    expect(
      restored.cycles.map((c) => c.edition.toJson()),
      books.map((b) => b.edition.toJson()),
    );
    expect(ReadingProgress(philosophyWorks, [restored]).completed, 0);
    expect(
      philosophyCatalogEditions
          .where((b) => b.workId == 'kant:pure-reason')
          .length,
      7,
    );
    expect(
      philosophyCatalogEditions
          .where((b) => b.workId == 'nagarjuna:mulamadhyamakakarika')
          .length,
      3,
    );
  });
  test('century options sort chronologically with unknown last', () {
    final values = ['21世紀', '2世紀', '紀元前4世紀', '不明', '10世紀', '紀元前6世紀', '1世紀']
      ..sort(compareReadingCenturies);
    expect(values, ['紀元前6世紀', '紀元前4世紀', '1世紀', '2世紀', '10世紀', '21世紀', '不明']);
  });
}
