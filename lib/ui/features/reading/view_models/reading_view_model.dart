import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/catalogs/philosophy_catalog.dart';
import '../../../../data/repositories/reading_repository.dart';
import '../../../../domain/models/philosophy_reading.dart';

class ReadingViewModel extends ChangeNotifier {
  ReadingViewModel(this.repository) {
    _session = repository.sessionKey;
    _subscription = repository.authChanges.listen((_) {
      if (_session != repository.sessionKey) {
        _session = repository.sessionKey;
        _records = [];
        _privateAuthors = [];
        error = null;
        unawaited(load());
      }
    });
  }

  final ReadingRepository repository;
  late final StreamSubscription<void> _subscription;
  String? _session;
  bool _disposed = false;
  int _generation = 0;
  List<ReadingRecord> _records = [];
  List<PhilosophyAuthor> _privateAuthors = [];
  bool loading = false;
  bool saving = false;
  String? error;

  bool get signedIn => repository.sessionKey != null;
  List<ReadingRecord> get records => List.unmodifiable(_records);
  List<PhilosophyWork> get works {
    final map = {for (final work in philosophyWorks) work.id: work};
    for (final record in _records) {
      map.putIfAbsent(record.work.id, () => record.work);
    }
    return map.values.toList(growable: false);
  }

  List<PhilosophyAuthor> get authors {
    final map = {for (final author in philosophyAuthors) author.id: author};
    for (final author in _privateAuthors) {
      map[author.id] = author;
    }
    for (final work in works) {
      map.putIfAbsent(work.author.id, () => work.author);
    }
    return map.values.toList(growable: false);
  }

  ReadingRecord? recordFor(String workId) {
    for (final record in _records) {
      if (record.work.id == workId) return record;
    }
    return null;
  }

  ReadingProgress progress(Iterable<PhilosophyWork> targets) =>
      ReadingProgress(targets, _records);

  Future<void> load() async {
    final generation = ++_generation;
    final session = repository.sessionKey;
    loading = session != null;
    error = null;
    _notify();
    if (session == null) {
      _records = [];
      _privateAuthors = [];
      _notify();
      return;
    }
    try {
      final records = await repository.list();
      final authors = await repository.authors();
      if (_disposed ||
          generation != _generation ||
          session != repository.sessionKey) {
        return;
      }
      _records = records;
      _privateAuthors = authors;
    } catch (failure) {
      if (generation == _generation && session == repository.sessionKey) {
        error = '読書記録を取得できませんでした。再試行してください';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (saving || !signedIn || loading) return false;
    final session = repository.sessionKey;
    saving = true;
    error = null;
    _notify();
    try {
      await action();
      return !_disposed && session == repository.sessionKey;
    } catch (failure) {
      if (session == repository.sessionKey) {
        error = failure is StateError
            ? failure.message.toString()
            : '保存できませんでした。入力を保持しています。再試行してください';
      }
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<bool> addWork(String id, PhilosophyWork work) => _mutate(() async {
        final session = repository.sessionKey;
        final recordId =
            work.id.startsWith('private:') || work.id.startsWith('legacy:')
                ? id
                : const Uuid()
                    .v5(Namespace.url.value, 'reading:$session:${work.id}');
        final result = await repository.add(recordId, work);
        if (session != repository.sessionKey) return;
        _replace(result);
      });

  Future<bool> appendWorkMemo(PhilosophyWork work, String text) async {
    final addition = text.trim();
    if (addition.isEmpty) return false;
    final record = recordFor(work.id);
    final current = record?.work ?? work;
    final note = [current.note, addition]
        .where((value) => value.isNotEmpty)
        .join('\n\n');
    if (note.length > 2000) {
      error = 'メモの合計は2000文字以内にしてください。既存のメモは保持しています';
      _notify();
      return false;
    }
    final updated = PhilosophyWork.fromJson({...current.toJson(), 'note': note});
    if (record == null) return addWork(const Uuid().v4(), updated);
    return save(
      ReadingRecord(
      id: record.id,
      work: updated,
      revision: record.revision,
      cycles: record.cycles,
      legacyStatus: record.legacyStatus,
      ),
    );
  }

  Future<bool> save(ReadingRecord record) => _mutate(() async {
        final session = repository.sessionKey;
        final result = await repository.save(record);
        if (session != repository.sessionKey) return;
        _replace(result);
      });

  Future<bool> addAuthor(String id, PhilosophyAuthor author) =>
      _mutate(() async {
        final session = repository.sessionKey;
        final result = await repository.addAuthor(id, author);
        if (session != repository.sessionKey) return;
        _privateAuthors = [
          ..._privateAuthors.where((a) => a.id != result.id),
          result,
        ];
      });

  void _replace(ReadingRecord record) {
    _records = [record, ..._records.where((r) => r.id != record.id)];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
