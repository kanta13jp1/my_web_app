import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/catalogs/philosophy_catalog.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';
import 'package:my_web_app/ui/features/reading/view_models/reading_view_model.dart';
import '../support/reading_fixture_repository.dart';

void main() {
  test(
      'legacy author presentation groups works without modifying saved records',
      () async {
    final repo = ReadingFixtureRepository();
    final model = ReadingViewModel(repo);
    await model.load();
    const work = PhilosophyWork(
        id: 'legacy:reading',
        title: '読書について',
        author: PhilosophyAuthor(id: 'legacy:schopenhauer', name: 'ショーペンハウエル'),);
    expect(await model.addWork('legacy-record', work), isTrue);
    final record = model.recordFor(work.id)!;
    expect(
        await model.save(record.withCycles(const [
          ReadingCycle(
              id: 'old-cycle',
              startedAt: '2026-10-12',
              edition: ReadingEdition(
                  totalPages: 160, translator: '斎藤忍随', isbn: '9784003363225',),
              entries: [
                ReadingEntry(
                    id: 'old-entry',
                    date: '2026-10-14',
                    pages: 91,
                    startPage: 1,
                    endPage: 91,
                    impression: '既存の感想',)
              ,],)
        ,]),),
        isTrue,);
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
