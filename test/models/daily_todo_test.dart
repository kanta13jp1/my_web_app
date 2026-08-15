import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/daily_todo.dart';

void main() {
  // 固定の「今日」。時刻付きでも日付のみへ正規化される前提。
  final now = DateTime(2026, 7, 31, 22, 0);
  final today = DateTime(2026, 7, 31);

  group('DailyTodoTask', () {
    test('予定日が過去で未完了なら繰り越し(借金)・日数付き', () {
      final task = DailyTodoTask(
        id: 't1',
        title: '請求確認',
        plannedDate: DateTime(2026, 7, 28),
      );
      expect(task.isCarriedOverAsOf(today), isTrue);
      expect(task.carryOverDaysAsOf(today), 3);
      expect(task.isForToday(today), isFalse);
    });

    test('今日の予定は繰り越しでない', () {
      final task = DailyTodoTask(id: 't2', title: '運動', plannedDate: now);
      expect(task.isForToday(today), isTrue);
      expect(task.isCarriedOverAsOf(today), isFalse);
      expect(task.carryOverDaysAsOf(today), 0);
    });

    test('完了済みは予定日が過去でも繰り越しにならない', () {
      final task = DailyTodoTask(
        id: 't3',
        title: '納税',
        plannedDate: DateTime(2026, 7, 20),
        completed: true,
        completedAt: DateTime(2026, 7, 21, 9),
      );
      expect(task.isCarriedOverAsOf(today), isFalse);
      expect(task.carryOverDaysAsOf(today), 0);
    });

    test('toJson/fromJson ラウンドトリップ', () {
      final task = DailyTodoTask(
        id: 't4',
        title: '掃除',
        plannedDate: DateTime(2026, 7, 30),
        completed: true,
        completedAt: DateTime(2026, 7, 30, 12, 34),
        note: 'メモ',
      );
      final restored = DailyTodoTask.fromJson(task.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 't4');
      expect(restored.title, '掃除');
      expect(restored.plannedDate, DateTime(2026, 7, 30));
      expect(restored.completed, isTrue);
      expect(restored.completedAt, isNotNull);
      expect(restored.note, 'メモ');
    });

    test('copyWith で completedAt を null へ戻せる(センチネル)', () {
      final task = DailyTodoTask(
        id: 't5',
        title: 'x',
        plannedDate: today,
        completed: true,
        completedAt: DateTime(2026, 7, 31, 8),
      );
      final reopened = task.copyWith(completed: false, completedAt: null);
      expect(reopened.completed, isFalse);
      expect(reopened.completedAt, isNull);
      // completedAt 未指定なら保持される。
      final kept = task.copyWith(title: 'y');
      expect(kept.completedAt, isNotNull);
    });

    test('id/title が欠けた壊れた JSON は null', () {
      expect(DailyTodoTask.fromJson(<String, dynamic>{'title': 'x'}), isNull);
      expect(
        DailyTodoTask.fromJson(<String, dynamic>{'id': 'a', 'title': ''}),
        isNull,
      );
      expect(DailyTodoTask.fromJson('not a map'), isNull);
    });
  });

  group('DailyTodoDigest.fromState', () {
    test('今日の集計と繰り越し借金を算出する', () {
      final tasks = <DailyTodoTask>[
        // 今日: 1件完了・1件未完了。
        DailyTodoTask(
          id: 'a',
          title: '今日A',
          plannedDate: today,
          completed: true,
          completedAt: DateTime(2026, 7, 31, 10),
        ),
        DailyTodoTask(id: 'b', title: '今日B', plannedDate: today),
        // 繰り越し2件(2日前・5日前)。
        DailyTodoTask(
          id: 'c',
          title: '借金C',
          plannedDate: DateTime(2026, 7, 29),
        ),
        DailyTodoTask(
          id: 'd',
          title: '借金D',
          plannedDate: DateTime(2026, 7, 26),
        ),
      ];
      final digest = DailyTodoDigest.fromState(
        tasks: tasks,
        log: const <DailyTodoCompletionLogEntry>[],
        now: now,
      );
      expect(digest.todayTotal, 2);
      expect(digest.todayCompleted, 1);
      expect(digest.todayPending, 1);
      expect(digest.carriedOverCount, 2);
      expect(digest.maxCarryOverDays, 5);
      // 古い順で並ぶ(5日前が先頭)。
      expect(digest.carriedOverTitles, <String>['借金D', '借金C']);
      expect(digest.isEmpty, isFalse);
    });

    test('完了ログと完了タスクの重複は同日同名で二重計上しない', () {
      final tasks = <DailyTodoTask>[
        DailyTodoTask(
          id: 'a',
          title: '重複',
          plannedDate: today,
          completed: true,
          completedAt: DateTime(2026, 7, 31, 9),
        ),
      ];
      final log = <DailyTodoCompletionLogEntry>[
        DailyTodoCompletionLogEntry(
          dateKey: dailyTodoDateKey(today),
          title: '重複',
          completedAt: DateTime(2026, 7, 31, 9),
        ),
        DailyTodoCompletionLogEntry(
          dateKey: dailyTodoDateKey(today),
          title: '別件',
          completedAt: DateTime(2026, 7, 31, 11),
        ),
      ];
      final digest =
          DailyTodoDigest.fromState(tasks: tasks, log: log, now: now);
      // 「重複」は1回、「別件」は1回 = 今日2件。
      expect(digest.completedLast7Days, 2);
      final todayRecent = digest.recentDays.first;
      expect(todayRecent.dateKey, dailyTodoDateKey(today));
      expect(todayRecent.completedTitles.toSet(), <String>{'重複', '別件'});
    });

    test('連続実行日数: 今日未完了でも昨日以前の連続は途切れない(猶予)', () {
      // 昨日・一昨日は完了、今日はまだ未完了。
      final log = <DailyTodoCompletionLogEntry>[
        DailyTodoCompletionLogEntry(
          dateKey: dailyTodoDateKey(DateTime(2026, 7, 30)),
          title: 'x',
          completedAt: DateTime(2026, 7, 30, 9),
        ),
        DailyTodoCompletionLogEntry(
          dateKey: dailyTodoDateKey(DateTime(2026, 7, 29)),
          title: 'y',
          completedAt: DateTime(2026, 7, 29, 9),
        ),
      ];
      final digest = DailyTodoDigest.fromState(
        tasks: const <DailyTodoTask>[],
        log: log,
        now: now,
      );
      expect(digest.activeStreakDays, 2);
    });

    test('連続実行日数: 今日も完了していれば今日を含めて数える', () {
      final log = <DailyTodoCompletionLogEntry>[
        for (final d in <DateTime>[
          DateTime(2026, 7, 31),
          DateTime(2026, 7, 30),
          DateTime(2026, 7, 29),
        ])
          DailyTodoCompletionLogEntry(
            dateKey: dailyTodoDateKey(d),
            title: 'x',
            completedAt: DateTime(d.year, d.month, d.day, 9),
          ),
      ];
      final digest = DailyTodoDigest.fromState(
        tasks: const <DailyTodoTask>[],
        log: log,
        now: now,
      );
      expect(digest.activeStreakDays, 3);
    });

    test('タスクもログも無ければ isEmpty かつ toAiJson は主要キーを持つ', () {
      final digest = DailyTodoDigest.fromState(
        tasks: const <DailyTodoTask>[],
        log: const <DailyTodoCompletionLogEntry>[],
        now: now,
      );
      expect(digest.isEmpty, isTrue);
      final json = digest.toAiJson();
      expect(json['today_total'], 0);
      expect(json['carried_over_count'], 0);
      expect(json.containsKey('recent_days'), isTrue);
      expect(json.containsKey('active_streak_days'), isTrue);
    });
  });
}
