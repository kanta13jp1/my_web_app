import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/custom_task_list_repository.dart';
import 'package:my_web_app/data/services/custom_task_list_ai_service.dart';
import 'package:my_web_app/data/services/custom_task_list_store.dart';
import 'package:my_web_app/domain/models/custom_task_list.dart';
import 'package:my_web_app/ui/features/custom_task_list/custom_task_list_feature.dart';

void main() {
  test(
    'generates, edits, completes, deletes, and persists a task list',
    () async {
      final store = _MemoryStore();
      final viewModel = CustomTaskListViewModel(
        repository: CustomTaskListRepositoryImpl(
          generator: const _FixedGenerator(),
          store: store,
          now: () => DateTime.utc(2026, 8, 24, 12),
        ),
      );

      final generated = await viewModel.generate(
        goal: '部屋を片付ける',
        situation: '毎日20分使える',
      );

      expect(generated, isTrue);
      expect(viewModel.items, hasLength(3));
      expect(store.snapshot?.items, hasLength(3));

      final firstId = viewModel.items.first.id;
      await viewModel.editTask(firstId, '  机の上を  片付ける  ');
      await viewModel.toggleTask(firstId);

      expect(viewModel.items.first.title, '机の上を 片付ける');
      expect(viewModel.items.first.isCompleted, isTrue);
      expect(viewModel.completedCount, 1);

      final lastId = viewModel.items.last.id;
      await viewModel.deleteTask(lastId);

      expect(viewModel.items, hasLength(2));
      expect(store.snapshot?.items, hasLength(2));
    },
  );

  test('requires either a goal or current situation', () async {
    final viewModel = CustomTaskListViewModel(
      repository: CustomTaskListRepositoryImpl(
        generator: const _FixedGenerator(),
        store: _MemoryStore(),
      ),
    );

    final generated = await viewModel.generate(goal: ' ', situation: ' ');

    expect(generated, isFalse);
    expect(viewModel.errorMessage, '目標または現状を入力してください。');
  });

  test('restores the last locally saved task list', () async {
    final store = _MemoryStore(
      CustomTaskListSnapshot(
        goal: '資格試験に合格する',
        situation: '朝30分勉強できる',
        items: const <CustomTaskItem>[
          CustomTaskItem(id: 'saved-1', title: '参考書を選ぶ'),
          CustomTaskItem(id: 'saved-2', title: '試験日を確認する'),
          CustomTaskItem(id: 'saved-3', title: '学習時間を予定に入れる'),
        ],
        source: 'saved',
        generatedAt: DateTime.utc(2026, 8, 23),
      ),
    );
    final viewModel = CustomTaskListViewModel(
      repository: CustomTaskListRepositoryImpl(
        generator: const _FixedGenerator(),
        store: store,
      ),
    );

    await viewModel.restore();

    expect(viewModel.goal, '資格試験に合格する');
    expect(viewModel.items, hasLength(3));
  });

  test('rolls back an edit when local persistence fails', () async {
    final original = CustomTaskListSnapshot(
      goal: '片付ける',
      situation: '',
      items: const <CustomTaskItem>[
        CustomTaskItem(id: 'task-1', title: '机を片付ける'),
      ],
      source: 'saved',
      generatedAt: DateTime.utc(2026, 8, 25),
    );
    final viewModel = CustomTaskListViewModel(
      repository: CustomTaskListRepositoryImpl(
        generator: const _FixedGenerator(),
        store: _FailingSaveStore(original),
      ),
    );
    await viewModel.restore();

    final saved = await viewModel.editTask('task-1', '変更後');

    expect(saved, isFalse);
    expect(viewModel.items.single.title, '机を片付ける');
    expect(viewModel.errorMessage, contains('保存できません'));
  });

  test('finishing generation after dispose does not notify a dead model',
      () async {
    final generator = _DeferredGenerator();
    final viewModel = CustomTaskListViewModel(
      repository: CustomTaskListRepositoryImpl(
        generator: generator,
        store: _MemoryStore(),
      ),
    );

    final generation = viewModel.generate(goal: '片付ける', situation: '');
    viewModel.dispose();
    generator.complete();

    expect(await generation, isTrue);
  });
}

class _MemoryStore implements CustomTaskListStore {
  CustomTaskListSnapshot? snapshot;

  _MemoryStore([this.snapshot]);

  @override
  Future<CustomTaskListSnapshot?> load() async => snapshot;

  @override
  Future<void> save(CustomTaskListSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _FixedGenerator implements CustomTaskListGenerator {
  const _FixedGenerator();

  @override
  Future<GeneratedCustomTaskList> generate({
    required String goal,
    required String situation,
  }) async {
    return const GeneratedCustomTaskList(
      taskTitles: <String>['机を空にする', '本を棚へ戻す', '床を掃除する'],
      source: 'test-ai',
    );
  }
}

class _FailingSaveStore implements CustomTaskListStore {
  final CustomTaskListSnapshot snapshot;

  _FailingSaveStore(this.snapshot);

  @override
  Future<CustomTaskListSnapshot?> load() async => snapshot;

  @override
  Future<void> save(CustomTaskListSnapshot snapshot) {
    throw StateError('disk full');
  }
}

class _DeferredGenerator implements CustomTaskListGenerator {
  final Completer<GeneratedCustomTaskList> _completer =
      Completer<GeneratedCustomTaskList>();

  void complete() {
    _completer.complete(
      const GeneratedCustomTaskList(
        taskTitles: <String>['机を空にする', '本を戻す', '床を掃除する'],
        source: 'test-ai',
      ),
    );
  }

  @override
  Future<GeneratedCustomTaskList> generate({
    required String goal,
    required String situation,
  }) =>
      _completer.future;
}
