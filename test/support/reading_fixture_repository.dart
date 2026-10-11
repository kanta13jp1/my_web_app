import 'dart:async';
import 'package:my_web_app/data/repositories/reading_repository.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';

class ReadingFixtureRepository implements ReadingRepository {
  String? user = 'fixture-user';
  final changes = StreamController<void>.broadcast();
  final items = <String, ReadingRecord>{};
  final privateAuthors = <String, PhilosophyAuthor>{};
  bool failNextSave = false;
  Completer<List<ReadingRecord>>? delayedList;

  @override
  String? get sessionKey => user;
  @override
  Stream<void> get authChanges => changes.stream;
  @override
  Future<List<ReadingRecord>> list() async =>
      delayedList?.future ?? items.values.toList();
  @override
  Future<List<PhilosophyAuthor>> authors() async =>
      privateAuthors.values.toList();
  @override
  Future<ReadingRecord> add(String id, PhilosophyWork work) async =>
      items.putIfAbsent(id, () => ReadingRecord(id: id, work: work));
  @override
  Future<PhilosophyAuthor> addAuthor(
          String id, PhilosophyAuthor author) async =>
      privateAuthors.putIfAbsent(id, () => author);
  @override
  Future<ReadingRecord> save(ReadingRecord record) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('保存失敗。入力を保持しています');
    }
    final old = items[record.id]!;
    if (old.revision != record.revision) throw StateError('別の画面で更新されました');
    final result = ReadingRecord(
        id: record.id,
        work: record.work,
        revision: record.revision + 1,
        cycles: record.cycles,
        legacyStatus: record.legacyStatus);
    items[record.id] = result;
    return result;
  }
}
