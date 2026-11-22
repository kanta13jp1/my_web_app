import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/daily_habits_page.dart';
import 'package:my_web_app/widgets/habit_resource_metrics_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user(String id) => User(
      id: id,
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-11-23T00:00:00Z',
    );

class _SessionAuth extends Fake implements GoTrueClient {
  final StreamController<AuthState> events =
      StreamController<AuthState>.broadcast();
  User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
}

class _SessionClient extends Fake implements SupabaseClient {
  @override
  final _SessionAuth auth = _SessionAuth();
}

double _relativeLuminance(Color color) {
  double linearize(double channel) {
    if (channel <= 0.03928) return channel / 12.92;
    return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('pure helpers parse values and compute all-clear streak without gaps', () {
    expect(DailyHabitsPage.safeInt(5), 5);
    expect(DailyHabitsPage.safeInt(15.0), 15);
    expect(DailyHabitsPage.safeInt('1,200'), 1200);
    expect(DailyHabitsPage.safeInt(null), isNull);

    final today = DateTime(2026, 11, 23);
    final activeIds = <String>{'h1', 'h2'};

    expect(
      DailyHabitsPage.calculateAllClearStreak(
        activeHabitIds: <String>{},
        completedDateToHabitIds: <String, Set<String>>{
          '2026-11-22': <String>{'h1', 'h2'},
        },
        today: today,
      ),
      0,
    );

    expect(
      DailyHabitsPage.calculateAllClearStreak(
        activeHabitIds: activeIds,
        completedDateToHabitIds: <String, Set<String>>{
          '2026-11-22': <String>{'h1', 'h2', 'archived-old'},
          '2026-11-21': <String>{'h1', 'h2'},
          '2026-11-20': <String>{'h1'},
          '2026-11-19': <String>{'h1', 'h2'},
        },
        today: today,
      ),
      2,
    );
  });

  testWidgets(
    'renders honest signed-out state with login navigation and zero FABs',
    (WidgetTester tester) async {
      final client = _SessionClient();
      addTearDown(client.auth.events.close);

      await tester.pumpWidget(
        MaterialApp(
          routes: <String, WidgetBuilder>{
            '/login': (_) => const Scaffold(body: Text('login-screen')),
          },
          home: DailyHabitsPage(supabaseClient: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('daily_habits_signed_out_state')),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('ログイン'));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
    },
  );

  testWidgets(
    'renders honest load error state and recovers to empty state on retry',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyHabitsPage(
            supabaseClient: client,
            loadSnapshot: (_, __) async {
              attempts += 1;
              if (attempts == 1) {
                throw StateError('network offline');
              }
              return const DailyHabitsSnapshot(
                habits: <Map<String, dynamic>>[],
                completedToday: <String>{},
                todayLogs: <String, Map<String, dynamic>>{},
                goals: <HabitGoalOption>[],
                allClearStreak: 0,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('daily_habits_error_state')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('daily_habits_empty_state')), findsNothing);

      await tester.tap(find.byKey(const Key('daily_habits_retry_button')));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.byKey(const Key('daily_habits_empty_state')), findsOneWidget);
    },
  );

  testWidgets(
    'toggle guard blocks double-tap duplicates and respects false return',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      final habits = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'hab-1',
          'title': 'マネーフォワード更新・財布残高入力',
          'description': '毎日夜に確認する',
          'is_active': true,
          'streak': 3.0,
          'best_streak': 5.0,
          'color_hex': '#4CAF50',
        },
      ];

      final gate = Completer<bool>();
      var toggleCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DailyHabitsPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 23, 9),
            loadSnapshot: (_, __) async => DailyHabitsSnapshot(
              habits: habits,
              completedToday: const <String>{},
              todayLogs: const <String, Map<String, dynamic>>{},
              goals: const <HabitGoalOption>[],
              allClearStreak: 2,
            ),
            toggleHabit: (_, __, ___, ____) {
              toggleCalls += 1;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('前日全達成ストリーク: 2日連続'), findsOneWidget);

      final toggleBtn =
          find.byKey(const Key('daily_habit_toggle_button_hab-1'));
      await tester.ensureVisible(toggleBtn);
      await tester.tap(toggleBtn);
      await tester.pump();
      expect(find.text('保存中'), findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pump();
      expect(toggleCalls, 1);

      gate.complete(false);
      await tester.pumpAndSettle();

      expect(find.text('既定値で完了を記録しました'), findsNothing);
      expect(
        find.text('習慣の達成状態を更新できませんでした。画面を更新してお試しください。'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'update today resource checks bool result cleanly without false success',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-2');
      addTearDown(client.auth.events.close);

      final habits = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'hab-2',
          'title': '読書する',
          'is_active': true,
          'streak': 1,
          'best_streak': 4,
          'color_hex': '#795548',
        },
      ];
      final todayLogs = <String, Map<String, dynamic>>{
        'hab-2': <String, dynamic>{
          'habit_id': 'hab-2',
          'time_cost_minutes': 20.0,
          'fatigue_score': 2.0,
          'goal_contribution_score': 60.0,
        },
      };

      var updateCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyHabitsPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 23, 9),
            loadSnapshot: (_, __) async => DailyHabitsSnapshot(
              habits: habits,
              completedToday: const <String>{'hab-2'},
              todayLogs: todayLogs,
              goals: const <HabitGoalOption>[],
              allClearStreak: 0,
            ),
            updateTodayResource: (_, __, ___, ____) async {
              updateCalls += 1;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editBtn = find.byKey(const ValueKey<String>('edit_habit_resource_hab-2'));
      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('今日の実績を修正'), findsOneWidget);
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();

      expect(updateCalls, 1);
      expect(find.text('今日の実績を更新しました'), findsNothing);
      expect(
        find.text('今日の実績を更新できませんでした。再読み込みしてお試しください。'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'delete habit checks confirmation and bool result cleanly',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-3');
      addTearDown(client.auth.events.close);

      final habits = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'hab-del',
          'title': '机を片付ける',
          'is_active': true,
          'streak': 0,
          'best_streak': 0,
          'color_hex': '#607D8B',
        },
      ];
      var allowDelete = false;
      var deleteCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DailyHabitsPage(
            supabaseClient: client,
            loadSnapshot: (_, __) async => DailyHabitsSnapshot(
              habits: habits,
              completedToday: const <String>{},
              todayLogs: const <String, Map<String, dynamic>>{},
              goals: const <HabitGoalOption>[],
              allClearStreak: 0,
            ),
            deleteHabit: (_, id) async {
              deleteCalls += 1;
              if (!allowDelete) return false;
              habits.removeWhere((h) => h['id'] == id);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('机を片付ける の操作メニュー'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      expect(find.text('習慣を削除'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(deleteCalls, 0);

      await tester.tap(find.byTooltip('机を片付ける の操作メニュー'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();
      expect(deleteCalls, 1);
      expect(find.text('削除対象が見つからず、削除できませんでした。'), findsOneWidget);
      expect(find.text('机を片付ける'), findsOneWidget);

      allowDelete = true;
      await tester.tap(find.byTooltip('机を片付ける の操作メニュー'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();
      expect(deleteCalls, 2);
      expect(find.text('机を片付ける'), findsNothing);
    },
  );

  testWidgets(
    'add habit dialog keeps description on empty title and inserts cleanly',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-4');
      addTearDown(client.auth.events.close);

      final habits = <Map<String, dynamic>>[];
      Map<String, dynamic>? savedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: DailyHabitsPage(
            supabaseClient: client,
            loadSnapshot: (_, __) async => DailyHabitsSnapshot(
              habits: habits,
              completedToday: const <String>{},
              todayLogs: const <String, Map<String, dynamic>>{},
              goals: const <HabitGoalOption>[],
              allClearStreak: 0,
            ),
            insertHabit: (payload) async {
              savedPayload = payload;
              habits.add(<String, dynamic>{
                'id': 'hab-new',
                'is_active': true,
                'streak': 0,
                'best_streak': 0,
                ...payload,
              });
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('daily_habits_appbar_add_button')),
      );
      await tester.pumpAndSettle();

      final descField = find.widgetWithText(TextField, '説明 (任意)');
      await tester.enterText(descField, '寝る前にコップ1杯');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('タスク名を入力してください'), findsOneWidget);
      expect(find.text('寝る前にコップ1杯'), findsOneWidget);
      expect(savedPayload, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'タスク名 *'),
        '水を飲む',
      );
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('標準コストを設定'), findsOneWidget);
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();

      expect(savedPayload?['title'], '水を飲む');
      expect(savedPayload?['description'], '寝る前にコップ1杯');
      expect(find.text('水を飲む'), findsOneWidget);
    },
  );

  testWidgets(
    'responsive at 320px@2x and meets Light/Dark contrast & a11y guidelines',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-5');
      addTearDown(client.auth.events.close);

      final habits = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'hab-a11y-1',
          'title': 'マネーフォワード更新・財布残高入力および家計簿レシート確認',
          'description': '毎晩21時に全口座の残高差額とレシートを確認する',
          'is_active': true,
          'streak': 14,
          'best_streak': 30,
          'color_hex': '#4CAF50',
        },
        <String, dynamic>{
          'id': 'hab-a11y-2',
          'title': '寝る前にキッチンをリセット',
          'is_active': true,
          'streak': 3,
          'best_streak': 7,
          'color_hex': 'invalid-hex',
        },
      ];
      final todayLogs = <String, Map<String, dynamic>>{
        'hab-a11y-1': <String, dynamic>{
          'habit_id': 'hab-a11y-1',
          'time_cost_minutes': 15,
          'fatigue_score': 2,
          'goal_contribution_score': 80,
        },
      };

      Future<void> pumpViewport(
        Size size,
        ThemeData theme,
        double scale,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<String>('${size.width}_${theme.brightness}_$scale'),
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: DailyHabitsPage(
              supabaseClient: client,
              nowProvider: () => DateTime(2026, 11, 23, 9),
              loadSnapshot: (_, __) async => DailyHabitsSnapshot(
                habits: habits,
                completedToday: const <String>{'hab-a11y-1'},
                todayLogs: todayLogs,
                goals: const <HabitGoalOption>[],
                allClearStreak: 5,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpViewport(const Size(320, 568), ThemeData.light(), 2.0);
      await pumpViewport(const Size(390, 844), ThemeData.dark(), 1.0);

      expect(
        _contrastRatio(const Color(0xFF9A3412), const Color(0xFFFFF3E0)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFFFFCC80), const Color(0xFF3E2209)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF283593)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFF9A3412), const Color(0xFFF8F9FE)),
        greaterThanOrEqualTo(4.5),
      );

      final handle = tester.ensureSemantics();
      await pumpViewport(const Size(1440, 1000), ThemeData.light(), 1.0);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await pumpViewport(const Size(390, 844), ThemeData.dark(), 1.0);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
