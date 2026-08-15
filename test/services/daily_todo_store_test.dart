import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/daily_todo.dart';
import 'package:my_web_app/services/daily_todo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = DailyTodoStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('save → load ラウンドトリップ(タスク+ログ+更新時刻)', () async {
    final p = await prefs();
    final tasks = <DailyTodoTask>[
      DailyTodoTask(id: 'a', title: 'A', plannedDate: DateTime(2026, 7, 31)),
    ];
    final log = <DailyTodoCompletionLogEntry>[
      DailyTodoCompletionLogEntry(
        dateKey: '2026-07-30',
        title: 'done',
        completedAt: DateTime(2026, 7, 30, 9),
      ),
    ];
    await store.save(
      tasks: tasks,
      log: log,
      updatedAt: DateTime(2026, 7, 31, 12),
      prefs: p,
    );
    final loaded = await store.load(prefs: p);
    expect(loaded.tasks.map((t) => t.id), <String>['a']);
    expect(loaded.log.map((e) => e.title), <String>['done']);
    expect(loaded.updatedAt, DateTime(2026, 7, 31, 12));
  });

  test('mergeRemote: リモートが新しければタスクを採用(LWW)・ログは和集合', () async {
    final p = await prefs();
    // ローカル: 古い更新時刻・タスク1件・ログ1件。
    await store.save(
      tasks: <DailyTodoTask>[
        DailyTodoTask(
          id: 'local',
          title: 'ローカル',
          plannedDate: DateTime(2026, 7, 31),
        ),
      ],
      log: <DailyTodoCompletionLogEntry>[
        DailyTodoCompletionLogEntry(
          dateKey: '2026-07-30',
          title: 'ローカル完了',
          completedAt: DateTime(2026, 7, 30, 9),
        ),
      ],
      updatedAt: DateTime(2026, 7, 31, 8),
      prefs: p,
    );
    // リモート: より新しい更新時刻・別タスク・別ログ。
    const remoteStore = DailyTodoStore();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final rp = await SharedPreferences.getInstance();
    await remoteStore.save(
      tasks: <DailyTodoTask>[
        DailyTodoTask(
          id: 'remote',
          title: 'リモート',
          plannedDate: DateTime(2026, 7, 31),
        ),
      ],
      log: <DailyTodoCompletionLogEntry>[
        DailyTodoCompletionLogEntry(
          dateKey: '2026-07-29',
          title: 'リモート完了',
          completedAt: DateTime(2026, 7, 29, 9),
        ),
      ],
      updatedAt: DateTime(2026, 7, 31, 20),
      prefs: rp,
    );
    final remoteValue = await remoteStore.encodeMirror(prefs: rp);

    final result = await store.mergeRemote(remoteValue, prefs: p);
    expect(result.changed, isTrue);
    // タスクはリモートを採用。
    expect(result.snapshot.tasks.map((t) => t.id), <String>['remote']);
    // ログは両方残る(和集合)。
    expect(
      result.snapshot.log.map((e) => e.title).toSet(),
      <String>{'ローカル完了', 'リモート完了'},
    );
  });

  test('mergeRemote: リモートが古ければタスクは保持・ログだけ補完', () async {
    final p = await prefs();
    await store.save(
      tasks: <DailyTodoTask>[
        DailyTodoTask(
          id: 'local',
          title: 'ローカル',
          plannedDate: DateTime(2026, 7, 31),
        ),
      ],
      log: const <DailyTodoCompletionLogEntry>[],
      updatedAt: DateTime(2026, 7, 31, 20),
      prefs: p,
    );
    // リモート: 古い更新時刻。タスクは採用されないが、ログは補完される。
    final remoteValue = <String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        DailyTodoTask(
          id: 'remote',
          title: 'リモート',
          plannedDate: DateTime(2026, 7, 31),
        ).toJson(),
      ],
      'log': <Map<String, dynamic>>[
        DailyTodoCompletionLogEntry(
          dateKey: '2026-07-29',
          title: '古い完了',
          completedAt: DateTime(2026, 7, 29, 9),
        ).toJson(),
      ],
      'updated_at': DateTime(2026, 7, 30, 8).toUtc().toIso8601String(),
    };
    final result = await store.mergeRemote(remoteValue, prefs: p);
    expect(result.changed, isTrue);
    // タスクはローカルのまま。
    expect(result.snapshot.tasks.map((t) => t.id), <String>['local']);
    // ログは補完された。
    expect(result.snapshot.log.map((e) => e.title), <String>['古い完了']);
  });

  test('mergeRemote: 変化が無ければ changed=false', () async {
    final p = await prefs();
    await store.save(
      tasks: <DailyTodoTask>[
        DailyTodoTask(id: 'a', title: 'A', plannedDate: DateTime(2026, 7, 31)),
      ],
      log: const <DailyTodoCompletionLogEntry>[],
      updatedAt: DateTime(2026, 7, 31, 20),
      prefs: p,
    );
    // 同じログ・古いタスク → 何も変わらない。
    final result = await store.mergeRemote(
      <String, dynamic>{
        'tasks': const <dynamic>[],
        'log': const <dynamic>[],
        'updated_at': DateTime(2026, 7, 30).toUtc().toIso8601String(),
      },
      prefs: p,
    );
    expect(result.changed, isFalse);
  });

  test('prune: 保持期間を超えた完了タスク/ログは間引くが未完了は残す', () async {
    final p = await prefs();
    final now = DateTime(2026, 7, 31, 12);
    await store.save(
      tasks: <DailyTodoTask>[
        // 未完了で大幅に過去 → 残る(繰り越し借金)。
        DailyTodoTask(
          id: 'old-open',
          title: '古い未完了',
          plannedDate: DateTime(2026, 1, 1),
        ),
        // 完了が保持期間(14日)より前 → 間引く。
        DailyTodoTask(
          id: 'old-done',
          title: '古い完了',
          plannedDate: DateTime(2026, 6, 1),
          completed: true,
          completedAt: DateTime(2026, 6, 1, 9),
        ),
      ],
      log: <DailyTodoCompletionLogEntry>[
        // 90日より前 → 間引く。
        DailyTodoCompletionLogEntry(
          dateKey: '2026-01-01',
          title: '大昔',
          completedAt: DateTime(2026, 1, 1, 9),
        ),
        // 最近 → 残る。
        DailyTodoCompletionLogEntry(
          dateKey: '2026-07-30',
          title: '最近',
          completedAt: DateTime(2026, 7, 30, 9),
        ),
      ],
      updatedAt: now,
      prefs: p,
    );
    final loaded = await store.load(prefs: p);
    expect(loaded.tasks.map((t) => t.id), <String>['old-open']);
    expect(loaded.log.map((e) => e.title), <String>['最近']);
  });

  test('空ならミラー値は null(不要な upsert を避ける)', () async {
    final p = await prefs();
    expect(await store.encodeMirror(prefs: p), isNull);
  });
}
