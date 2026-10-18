import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/models/weekly_habit.dart';
import 'package:my_web_app/services/weekly_habit_store.dart';
import 'package:my_web_app/widgets/weekly_habit_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'JST boundary and multiple Wednesday/Thursday defaults',
    () {
      expect(
        WeeklyHabitState.japanDate(DateTime.parse('2026-10-18T14:59:59Z')),
        DateTime.utc(2026, 10, 18),
      );
      expect(
        WeeklyHabitState.japanDate(DateTime.parse('2026-10-18T15:00:00Z')),
        DateTime.utc(2026, 10, 19),
      );
      final state = WeeklyHabitState.initial();
      expect(
        state.forDate(DateTime.utc(2026, 10, 21)).map((h) => h.title),
        ['アプリ開発', '口座残高更新'],
      );
      expect(
        state.forDate(DateTime.utc(2026, 10, 22)).map((h) => h.title),
        ['洗い物', '株の整理'],
      );
    },
  );
  test(
    'individual completion, edit, removal and cancellation retain history',
    () {
      final day = DateTime.utc(2026, 10, 21);
      final initial = WeeklyHabitState.initial();
      final both = initial.forDate(day);
      var state = initial
          .withCompleted(day, both[0], true)
          .withCompleted(day, both[1], true);
      state = state.withCompleted(day, both[0], false);
      expect(state.completion(day, both[0].id), isNull);
      expect(state.completion(day, both[1].id), isNotNull);
      state = state.withHabit(WeeklyHabit(both[1].id, 4, '残高', '1件'));
      expect(state.completion(day, both[1].id)!.minimum, '1口座の残高を確認して更新');
      state = state.withoutHabit(both[1].id);
      expect(state.completions.length, 1);
      expect(
        state.withoutCompletion(state.completions.keys.single).completions,
        isEmpty,
      );
      expect(
        state.completion(day.add(const Duration(days: 1)), both[1].id),
        isNull,
      );
    },
  );
  test(
    'v1 migration preserves wording and individual historical achievement',
    () {
      final legacy = {
        'version': 1,
        'habits': [
          for (var d = 1; d <= 7; d++)
            {'weekday': d, 'title': '旧$d', 'minimum': '最低$d'},
        ],
        'completions': {
          '2026-10-21': {'title': '旧3', 'minimum': '最低3'}
        },
      };
      final migrated = WeeklyHabitState.fromJson(legacy);
      expect(migrated.forDate(DateTime.utc(2026, 10, 21)).length, 2);
      expect(migrated.completions['2026-10-21/legacy-3']!.minimum, '最低3');
      expect(migrated.completions.length, 1);
      expect(
          WeeklyHabitState.fromJson(migrated.toJson()).completions.length, 1);
    },
  );
  test(
    'schema rejects corruption but accepts additional fields',
    () {
      final valid = WeeklyHabitState.initial().toJson();
      expect(
        WeeklyHabitState.fromJson({...valid, 'extra': true}).habits.length,
        9,
      );
      for (final bad in [
        {...valid, 'version': 99},
        {...valid, 'habits': 'broken'},
        {...valid, 'completions': []},
        {
          ...valid,
          'habits': [
            {'id': 'bad', 'weekday': 8, 'title': 'a', 'minimum': 'b'},
          ]
        },
      ]) {
        expect(() => WeeklyHabitState.fromJson(bad), throwsFormatException);
      }
    },
  );
  test(
    'storage restores and isolates accounts without overwriting invalid data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WeeklyHabitStore(prefs, userId: 'alice');
      final state = WeeklyHabitState.initial();
      final day = DateTime.utc(2026, 10, 21);
      await store.save(state.withCompleted(day, state.forDate(day).last, true));
      await prefs.reload();
      expect(
        WeeklyHabitStore(prefs, userId: 'alice').load().completions.length,
        1,
      );
      expect(
          WeeklyHabitStore(prefs, userId: 'bob').load().completions, isEmpty);
      await prefs.setString(store.key, 'broken');
      expect(store.load, throwsFormatException);
      expect(prefs.getString(store.key), 'broken');
    },
  );
  testWidgets(
    '360px multiple independent checks survive remount',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app() => MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WeeklyHabitCard(
                  userId: 'alice',
                  now: () => DateTime.utc(2026, 10, 21),
                ),
              ),
            ),
          );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNWidgets(2));
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, false);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'history tap remains today and follows JST midnight',
    (tester) async {
      var now = DateTime.utc(2026, 10, 19, 14, 59);
      final prefs = await SharedPreferences.getInstance();
      final state = WeeklyHabitState.initial();
      await WeeklyHabitStore(prefs, userId: 'alice').save(
        state.withCompleted(
          DateTime.utc(2026, 10, 19),
          state.habits.first,
          true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyHabitCard(userId: 'alice', now: () => now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('達成履歴（1件）'));
      await tester.tap(find.text('達成履歴（1件）'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('2026-10-19：ギターの練習'));
      await tester.tap(find.text('2026-10-19：ギターの練習'));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-19（月）日本時間・今日'), findsOneWidget);
      now = DateTime.utc(2026, 10, 19, 15);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-20（火）日本時間・今日'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
