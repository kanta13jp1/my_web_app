import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/catalogs/philosophy_catalog.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';
import 'package:my_web_app/ui/features/reading/view_models/reading_view_model.dart';
import '../support/reading_fixture_repository.dart';

void main() {
  test('guest can browse but cannot mutate; save failure leaves the previous record intact', () async {
    final repo = ReadingFixtureRepository(); final model = ReadingViewModel(repo);
    await model.load(); final work = philosophyWorks.first;
    expect(await model.addWork('id', work), isTrue);
    final old = model.recordFor(work.id)!;
    repo.failNextSave = true;
    expect(await model.save(old.withCycles(const [ReadingCycle(id: 'cycle', startedAt: '2026-10-11')])), isFalse);
    expect(model.recordFor(work.id)!.cycles, isEmpty);
    expect(await model.save(old.withCycles(const [ReadingCycle(id: 'cycle', startedAt: '2026-10-11')])), isTrue);
    await model.load(); expect(model.recordFor(work.id)!.cycles.length, 1);
    repo.user = null; repo.changes.add(null); await Future<void>.delayed(Duration.zero);
    expect(model.records, isEmpty); expect(model.works.length, 17);
    expect(await model.addWork('other', work), isFalse);
    model.dispose(); await repo.changes.close();
  });
  test('late previous-account response cannot restore private records', () async {
    final repo = ReadingFixtureRepository(); final model = ReadingViewModel(repo);
    final delayed = Completer<List<ReadingRecord>>(); repo.delayedList = delayed;
    final request = model.load(); repo.user = null; repo.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    delayed.complete([ReadingRecord(id: 'private', work: philosophyWorks.first)]);
    await request; expect(model.records, isEmpty);
    model.dispose(); await repo.changes.close();
  });
}
