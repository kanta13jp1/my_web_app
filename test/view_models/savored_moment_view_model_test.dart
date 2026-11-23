import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/savored_moment_repository.dart';
import 'package:my_web_app/domain/models/savored_moment.dart';
import 'package:my_web_app/view_models/savored_moment_view_model.dart';

void main() {
  late MemorySavoredMomentRepository repository;
  late SavoredMomentViewModel viewModel;

  setUp(() {
    repository = MemorySavoredMomentRepository();
    viewModel = SavoredMomentViewModel(
      repository: repository,
      userId: 'user-1',
      clock: () => DateTime(2026, 11, 17, 21),
    );
  });

  tearDown(() => viewModel.dispose());

  test('loads the recall window and splits today from recent', () async {
    repository.stored.addAll([
      SavoredMoment(
        id: 1,
        note: '散歩中に金木犀の匂いがした',
        momentDate: DateTime(2026, 11, 15),
        createdAt: DateTime(2026, 11, 15, 18),
      ),
      SavoredMoment(
        id: 2,
        note: '味噌汁がおいしかった',
        momentDate: DateTime(2026, 11, 17),
        createdAt: DateTime(2026, 11, 17, 8),
      ),
    ]);

    await viewModel.load();

    expect(repository.lastSince, DateTime(2026, 11, 4));
    expect(viewModel.loadFailed, isFalse);
    expect(viewModel.digest.today.single.note, '味噌汁がおいしかった');
    expect(viewModel.digest.recent.single.note, '散歩中に金木犀の匂いがした');
  });

  test('saves a trimmed line and shows it immediately', () async {
    await viewModel.load();

    expect(await viewModel.add('  夕焼けがきれいだった  '), isTrue);

    expect(repository.lastNote, '夕焼けがきれいだった');
    expect(repository.lastDate, DateTime(2026, 11, 17, 21));
    expect(viewModel.digest.today.single.note, '夕焼けがきれいだった');
  });

  test('rejects blank and over-long lines without calling the server',
      () async {
    await viewModel.load();

    expect(await viewModel.add('   '), isFalse);
    expect(await viewModel.add('あ' * 201), isFalse);

    expect(repository.addCalls, 0);
    expect(viewModel.saveError, isNull);
  });

  test('a failed read is reported, and today can still be saved', () async {
    repository.failLoad = true;

    await viewModel.load();

    expect(viewModel.loadFailed, isTrue);
    expect(viewModel.digest.today, isEmpty);
    expect(await viewModel.add('温かいお茶がおいしかった'), isTrue);
    expect(viewModel.digest.today.single.note, '温かいお茶がおいしかった');
  });

  test('a failed save keeps the list unchanged and exposes a message',
      () async {
    await viewModel.load();
    repository.failAdd = true;

    expect(await viewModel.add('星が見えた'), isFalse);

    expect(viewModel.saveError, contains('保存できませんでした'));
    expect(viewModel.digest.today, isEmpty);
    expect(viewModel.isSaving, isFalse);
  });

  test('does nothing when signed out', () async {
    final signedOut = SavoredMomentViewModel(
      repository: repository,
      userId: null,
    );
    addTearDown(signedOut.dispose);

    await signedOut.load();

    expect(signedOut.isAuthenticated, isFalse);
    expect(await signedOut.add('星が見えた'), isFalse);
    expect(repository.loadCalls, 0);
    expect(repository.addCalls, 0);
  });
}

class MemorySavoredMomentRepository implements SavoredMomentRepository {
  final stored = <SavoredMoment>[];
  bool failLoad = false;
  bool failAdd = false;
  int loadCalls = 0;
  int addCalls = 0;
  DateTime? lastSince;
  DateTime? lastDate;
  String? lastNote;
  int _nextId = 100;

  @override
  Future<List<SavoredMoment>> loadSince({
    required String userId,
    required DateTime since,
  }) async {
    loadCalls++;
    if (failLoad) throw StateError('offline');
    lastSince = since;
    return List.of(stored);
  }

  @override
  Future<SavoredMoment> add({
    required String userId,
    required DateTime date,
    required String note,
  }) async {
    addCalls++;
    if (failAdd) throw StateError('offline');
    lastDate = date;
    lastNote = note;
    final saved = SavoredMoment(
      id: _nextId++,
      note: note,
      momentDate: DateTime(date.year, date.month, date.day),
      createdAt: date,
    );
    stored.add(saved);
    return saved;
  }
}
