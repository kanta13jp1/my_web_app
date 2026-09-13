import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/services/custom_task_list_store.dart';
import 'package:my_web_app/domain/models/custom_task_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('round-trips the generated list and completion state', () async {
    const store = SharedPreferencesCustomTaskListStore();
    final snapshot = CustomTaskListSnapshot(
      goal: '部屋を片付ける',
      situation: '毎日20分使える',
      items: const <CustomTaskItem>[
        CustomTaskItem(
          id: 'task-1',
          title: '机を空にする',
          isCompleted: true,
        ),
        CustomTaskItem(id: 'task-2', title: '本を棚へ戻す'),
        CustomTaskItem(id: 'task-3', title: '床を掃除する'),
      ],
      source: 'ai-hub provider.chat_auto',
      generatedAt: DateTime.utc(2026, 8, 24, 13),
    );

    await store.save(snapshot);
    final restored = await store.load();

    expect(restored?.goal, snapshot.goal);
    expect(restored?.items, hasLength(3));
    expect(restored?.items.first.isCompleted, isTrue);
    expect(restored?.source, snapshot.source);
    expect(restored?.generatedAt, snapshot.generatedAt);
  });

  test('treats malformed saved data as an empty state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesCustomTaskListStore.storageKey: '{broken',
    });

    const store = SharedPreferencesCustomTaskListStore();

    expect(await store.load(), isNull);
  });
}
