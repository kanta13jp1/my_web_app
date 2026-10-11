import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/catalogs/philosophy_catalog.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';

void main() {
  test('catalog identity, sources and BCE compound classification', () {
    expect(philosophyAuthors.length, 13);
    expect(philosophyWorks.length, 17);
    expect(philosophyWorks.map((w) => w.id).toSet().length, 17);
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
    expect(progress.total, 17);
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
}
