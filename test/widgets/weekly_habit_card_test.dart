import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/models/weekly_habit.dart';
import 'package:my_web_app/services/weekly_habit_store.dart';
import 'package:my_web_app/widgets/weekly_habit_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'unknown fields survive compatibility while corrupt containers reject loading',
      () {
    final valid = WeeklyHabitState.initial().toJson();
    expect(
        WeeklyHabitState.fromJson({...valid, 'future_field': true})
            .habits
            .length,
        7);
    for (final corrupt in [
      {...valid, 'version': 2},
      {...valid, 'habits': 'broken'},
      {...valid, 'habits': []},
      {...valid, 'completions': []},
      {
        ...valid,
        'completions': {
          '2026-02-31': {'title': 'a', 'minimum': 'b'}
        }
      },
    ]) {
      expect(() => WeeklyHabitState.fromJson(corrupt), throwsFormatException);
    }
  });

  testWidgets('today history selection stays on JST day and follows midnight',
      (tester) async {
    var now = DateTime.utc(2026, 10, 19, 14, 59);
    final prefs = await SharedPreferences.getInstance();
    await WeeklyHabitStore(prefs, userId: 'alice').save(
      WeeklyHabitState.initial()
          .withCompleted(DateTime.utc(2026, 10, 19), true),
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: WeeklyHabitCard(userId: 'alice', now: () => now),
    ))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('達成履歴（1日）'));
    await tester.tap(find.text('達成履歴（1日）'));
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
  });

  test('JST midnight changes the weekday independently of device timezone', () {
    expect(WeeklyHabitState.japanDate(DateTime.parse('2026-10-18T14:59:59Z')),
        DateTime.utc(2026, 10, 18));
    expect(WeeklyHabitState.japanDate(DateTime.parse('2026-10-18T15:00:00Z')),
        DateTime.utc(2026, 10, 19));
    final state = WeeklyHabitState.initial();
    expect(state.forDate(DateTime.utc(2026, 10, 19)).title, 'ギターの練習');
    expect(state.forDate(DateTime.utc(2026, 10, 18)).title, 'レシート整理');
  });

  test(
      'completion is reversible, date specific, and retains its original minimum',
      () {
    final day = DateTime.utc(2026, 10, 19);
    final completed = WeeklyHabitState.initial().withCompleted(day, true);
    final edited = completed.withHabit(const WeeklyHabit(1, 'ギター', '1分'));
    expect(edited.completions['2026-10-19']!.minimum, '手に取って5分弾く');
    expect(edited.completions.containsKey('2026-10-20'), false);
    expect(edited.withCompleted(day, false).completions, isEmpty);
  });

  test(
      'settings and completion restore after storage reload and isolate accounts',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final store = WeeklyHabitStore(prefs, userId: 'alice');
    final value = WeeklyHabitState.initial()
        .withHabit(const WeeklyHabit(2, '読む', '1ページ'))
        .withCompleted(DateTime.utc(2026, 10, 20), true);
    await store.save(value);
    await prefs.reload();
    final restored = WeeklyHabitStore(prefs, userId: 'alice').load();
    expect(restored.habits[1].minimum, '1ページ');
    expect(restored.completions['2026-10-20']!.title, '読む');
    expect(WeeklyHabitStore(prefs, userId: 'bob').load().completions, isEmpty);
    await prefs.setString(store.key, 'malformed');
    expect(store.load, throwsFormatException);
    expect(prefs.getString(store.key), 'malformed');
  });

  testWidgets('narrow card marks and reverses a day, restoring on remount',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget app() => MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: WeeklyHabitCard(
              userId: 'alice', now: () => DateTime.utc(2026, 10, 18, 16)),
        )));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('ギターの練習'), findsOneWidget);
    expect(find.textContaining('2026-10-19（月）'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed read disables writes and signed out card never saves',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'asset_weekly_habits_v1_alice': 'broken'});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: WeeklyHabitCard(
          userId: 'alice', now: () => DateTime.utc(2026, 10, 19)),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('読込に失敗'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: WeeklyHabitCard(userId: null),
    ))));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
