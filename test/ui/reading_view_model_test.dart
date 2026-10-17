import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/catalogs/philosophy_catalog.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';
import 'package:my_web_app/ui/features/reading/view_models/reading_view_model.dart';
import '../support/reading_fixture_repository.dart';

void main() {
  test('duplicate works keep separate editions and save only the cycle owner',
      () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    await model.load();
    final shared =
        philosophyWorks.firstWhere((work) => work.id == 'plato:republic');
    const legacy = PhilosophyWork(
      id: 'legacy:republic',
      title: '国家',
      author: PhilosophyAuthor(id: 'old-plato', name: 'Plato'),
      note: '古い著作メモ',
    );
    expect(await model.addWork('shared-record', shared), isTrue);
    final first = model.recordFor(shared.id)!;
    expect(
      await model.save(
        first.withCycles(const [
          ReadingCycle(
            id: 'same-cycle',
            startedAt: '2026-10-12',
            status: 'read',
            edition: ReadingEdition(publisher: '版A', totalPages: 100),
            entries: [
              ReadingEntry(
                id: 'entry-a',
                date: '2026-10-12',
                pages: 10,
                endPage: 10,
                impression: '感想A',
              ),
            ],
          ),
        ]),
      ),
      isTrue,
    );
    expect(await model.addWork('legacy-record', legacy), isTrue);
    final second =
        model.records.singleWhere((record) => record.work.id == legacy.id);
    expect(
      await model.save(
        second.withCycles(const [
          ReadingCycle(
            id: 'same-cycle',
            startedAt: '2026-10-14',
            edition: ReadingEdition(publisher: '版B', totalPages: 160),
            entries: [
              ReadingEntry(
                id: 'entry-b',
                date: '2026-10-14',
                pages: 20,
                endPage: 20,
                impression: '感想B',
              ),
            ],
          ),
        ]),
      ),
      isTrue,
    );
    final before = {
      for (final record in model.records) record.id: record.savePayload(),
    };
    await model.load();
    expect(model.works.length, philosophyWorks.length);
    expect(model.works.where((work) => work.title == '国家').length, 1);
    expect(model.recordsFor(shared.id).length, 2);
    expect(model.recordsFor(legacy.id).length, 2);
    expect(model.cyclesFor(shared.id).length, 2);
    expect(model.statusFor(shared.id), 'reading');
    final progress = model.progress([shared]);
    expect(progress.total, 1);
    expect(progress.completed, 1);
    expect(progress.reading, 1);
    expect(progress.pages, 30);
    expect(
      {for (final record in model.records) record.id: record.savePayload()},
      before,
    );
    final owner = model.cyclesFor(shared.id).last.$1;
    final oldCycle = owner.cycles.single;
    expect(
      await model.save(
        owner.withCycles([
          oldCycle.copyWith(
            edition: const ReadingEdition(publisher: '版B編集', totalPages: 160),
          ),
        ]),
      ),
      isTrue,
    );
    await model.load();
    expect(
      model.records
          .singleWhere((record) => record.id == first.id)
          .savePayload(),
      before[first.id],
    );
    final edited = model.records.singleWhere((record) => record.id == owner.id);
    expect(edited.work.toJson(), legacy.toJson());
    expect(edited.cycles.single.entries.single.impression, '感想B');
    expect(edited.cycles.single.reachedPage, 20);
    expect(edited.cycles.single.edition.publisher, '版B編集');
    model.dispose();
    await repo.changes.close();
  });

  test(
      'legacy author presentation groups works without modifying saved records',
      () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    await model.load();
    const work = PhilosophyWork(
      id: 'legacy:reading',
      title: '読書について',
      author: PhilosophyAuthor(id: 'legacy:schopenhauer', name: 'ショーペンハウエル'),
    );
    expect(await model.addWork('legacy-record', work), isTrue);
    final record = model.recordFor(work.id)!;
    expect(
      await model.save(
        record.withCycles(const [
          ReadingCycle(
            id: 'old-cycle',
            startedAt: '2026-10-12',
            edition: ReadingEdition(
              totalPages: 160,
              translator: '斎藤忍随',
              isbn: '9784003363225',
            ),
            entries: [
              ReadingEntry(
                id: 'old-entry',
                date: '2026-10-14',
                pages: 91,
                startPage: 1,
                endPage: 91,
                impression: '既存の感想',
              ),
            ],
          ),
        ]),
      ),
      isTrue,
    );
    final saved = model.recordFor(work.id)!.savePayload();
    await model.load();
    expect(model.authors.where((a) => a.name.startsWith('ショーペン')).length, 1);
    final displayed = model.works.firstWhere((w) => w.id == work.id);
    expect(displayed.author.id, 'schopenhauer');
    expect(displayed.author.name, 'ショーペンハウアー');
    expect(model.works.where((w) => w.author.id == 'schopenhauer').length, 2);
    expect(model.recordFor(work.id)!.savePayload(), saved);
    expect(model.recordFor(work.id)!.work.author.id, 'legacy:schopenhauer');
    expect(model.recordFor(work.id)!.cycles.single.reachedPage, 91);
    model.dispose();
    await repo.changes.close();
  });

  test('work memo persists without starting a reading cycle', () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    await model.load();
    final work = philosophyWorks.first;
    expect(await model.appendWorkMemo(work, '画像確認16〜17頁'), isTrue);
    await model.load();
    final record = model.recordFor(work.id)!;
    expect(record.work.note, contains('画像確認16〜17頁'));
    expect(record.cycles, isEmpty);
    expect(record.pagesRead, 0);
    expect(record.isRead, isFalse);
    repo.failNextSave = true;
    expect(await model.appendWorkMemo(work, '追加失敗'), isFalse);
    expect(model.recordFor(work.id)!.work.note, record.work.note);
    expect(await model.appendWorkMemo(work, '追記成功'), isTrue);
    await model.load();
    expect(model.recordFor(work.id)!.work.note, contains('追記成功'));
    expect(model.recordFor(work.id)!.cycles, isEmpty);
    model.dispose();
    await repo.changes.close();
  });

  test('long work memo survives reload and overflow preserves existing memo',
      () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    await model.load();
    final work = philosophyWorks.first;
    final text = List.filled(3000, '本').join();
    expect(await model.appendWorkMemo(work, text), isTrue);
    expect(await model.appendWorkMemo(work, '12〜15頁の目次'), isTrue);
    await model.load();
    final record = model.recordFor(work.id)!;
    expect(record.work.note, contains(text));
    expect(record.work.note, endsWith('12〜15頁の目次'));
    expect(record.cycles, isEmpty);
    expect(record.pagesRead, 0);
    expect(record.isRead, isFalse);
    expect(
      await model.appendWorkMemo(work, List.filled(100000, '字').join()),
      isFalse,
    );
    expect(model.recordFor(work.id)!.work.note, record.work.note);
    repo.failNextSave = true;
    expect(await model.appendWorkMemo(work, '保存失敗'), isFalse);
    expect(model.recordFor(work.id)!.work.note, record.work.note);
    model.dispose();
    await repo.changes.close();
  });

  test(
      'guest can browse but cannot mutate; save failure leaves the previous record intact',
      () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    await model.load();
    final work = philosophyWorks.first;
    expect(await model.addWork('id', work), isTrue);
    final old = model.recordFor(work.id)!;
    repo.failNextSave = true;
    expect(
      await model.save(
        old.withCycles(
          const [ReadingCycle(id: 'cycle', startedAt: '2026-10-11')],
        ),
      ),
      isFalse,
    );
    expect(model.recordFor(work.id)!.cycles, isEmpty);
    expect(
      await model.save(
        old.withCycles(
          const [ReadingCycle(id: 'cycle', startedAt: '2026-10-11')],
        ),
      ),
      isTrue,
    );
    await model.load();
    expect(model.recordFor(work.id)!.cycles.length, 1);
    repo.user = null;
    repo.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(model.records, isEmpty);
    expect(model.works.length, philosophyWorks.length);
    expect(await model.addWork('other', work), isFalse);
    model.dispose();
    await repo.changes.close();
  });
  test('late previous-account response cannot restore private records',
      () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    final delayed = Completer<List<ReadingRecord>>();
    repo.delayedList = delayed;
    final request = model.load();
    repo.user = null;
    repo.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    delayed
        .complete([ReadingRecord(id: 'private', work: philosophyWorks.first)]);
    await request;
    expect(model.records, isEmpty);
    model.dispose();
    await repo.changes.close();
  });
}
