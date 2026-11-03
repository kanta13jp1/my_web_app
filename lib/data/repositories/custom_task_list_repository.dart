import '../../domain/models/custom_task_list.dart';
import '../services/custom_task_list_ai_service.dart';
import '../services/custom_task_list_store.dart';

abstract class CustomTaskListRepository {
  Future<CustomTaskListSnapshot?> load();

  Future<CustomTaskListSnapshot> generate({
    required String goal,
    required String situation,
  });

  Future<void> save(CustomTaskListSnapshot snapshot);
}

class CustomTaskListRepositoryImpl implements CustomTaskListRepository {
  final CustomTaskListGenerator _generator;
  final CustomTaskListStore _store;
  final DateTime Function() _now;

  CustomTaskListRepositoryImpl({
    CustomTaskListGenerator generator = const AiCustomTaskListGenerator(),
    CustomTaskListStore store = const SharedPreferencesCustomTaskListStore(),
    DateTime Function()? now,
  })  : _generator = generator,
        _store = store,
        _now = now ?? DateTime.now;

  @override
  Future<CustomTaskListSnapshot?> load() => _store.load();

  @override
  Future<CustomTaskListSnapshot> generate({
    required String goal,
    required String situation,
  }) async {
    final generated = await _generator.generate(
      goal: goal,
      situation: situation,
    );
    final generatedAt = _now();
    final snapshot = CustomTaskListSnapshot(
      goal: goal.trim(),
      situation: situation.trim(),
      items: List<CustomTaskItem>.generate(
        generated.taskTitles.length,
        (index) => CustomTaskItem(
          id: '${generatedAt.microsecondsSinceEpoch}-$index',
          title: generated.taskTitles[index],
        ),
        growable: false,
      ),
      source: generated.source,
      generatedAt: generatedAt,
    );
    await _store.save(snapshot);
    return snapshot;
  }

  @override
  Future<void> save(CustomTaskListSnapshot snapshot) => _store.save(snapshot);
}
