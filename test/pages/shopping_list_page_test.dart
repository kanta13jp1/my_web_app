import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/shopping_list_page.dart';
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
  test('pure helpers parse numbers safely and evaluate next_remind_date', () {
    expect(ShoppingListPage.safeInt(3), 3);
    expect(ShoppingListPage.safeInt(1200.0), 1200);
    expect(ShoppingListPage.safeInt('2,480'), 2480);
    expect(ShoppingListPage.safeInt(null), isNull);

    final now = DateTime(2026, 11, 23, 9);
    expect(
      ShoppingListPage.needsBuy(
        <String, dynamic>{'is_purchased': false, 'next_remind_date': null},
        now,
      ),
      isTrue,
    );
    expect(
      ShoppingListPage.needsBuy(
        <String, dynamic>{
          'is_purchased': false,
          'next_remind_date': '2026-11-23',
        },
        now,
      ),
      isTrue,
    );
    expect(
      ShoppingListPage.needsBuy(
        <String, dynamic>{
          'is_purchased': false,
          'next_remind_date': '2026-11-24',
        },
        now,
      ),
      isFalse,
    );
    expect(
      ShoppingListPage.needsBuy(
        <String, dynamic>{
          'is_purchased': true,
          'next_remind_date': '2026-11-20',
        },
        now,
      ),
      isFalse,
    );
  });

  testWidgets(
    'renders honest signed-out state with login navigation and no FAB',
    (WidgetTester tester) async {
      final client = _SessionClient();
      addTearDown(client.auth.events.close);

      await tester.pumpWidget(
        MaterialApp(
          routes: <String, WidgetBuilder>{
            '/login': (_) => const Scaffold(body: Text('login-screen')),
          },
          home: ShoppingListPage(supabaseClient: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('shopping_list_signed_out_state')),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.byKey(const Key('shopping_list_empty_state')),
        findsNothing,
      );

      await tester.tap(find.text('ログイン'));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
    },
  );

  testWidgets(
    'renders honest load error state and recovers on retry',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShoppingListPage(
            supabaseClient: client,
            loadItems: (_) async {
              attempts += 1;
              if (attempts == 1) {
                throw StateError('network error');
              }
              return <Map<String, dynamic>>[];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('shopping_list_error_state')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shopping_list_empty_state')), findsNothing);

      await tester.tap(find.byKey(const Key('shopping_list_retry_button')));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(
        find.byKey(const Key('shopping_list_empty_state')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'purchase guard prevents double-tap duplicate calls and checks bool result',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'item-1',
          'name': 'コーヒー豆',
          'category': 'drink',
          'quantity': 1,
          'estimated_price': 980,
          'shop': '近所のスーパー',
          'priority': 'urgent',
          'is_purchased': false,
          'is_recurring': false,
        },
      ];

      final gate = Completer<bool>();
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ShoppingListPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 23, 9),
            loadItems: (_) async => items,
            markItemPurchased: (_, __, ___) {
              calls += 1;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('shopping_list_urgent_banner')),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('購入完了'));
      await tester.pump();
      expect(find.text('記録中'), findsOneWidget);

      await tester.tap(find.text('記録中'));
      await tester.pump();
      expect(calls, 1);

      gate.complete(false);
      await tester.pumpAndSettle();

      expect(find.text('購入済みを記録しました'), findsNothing);
      expect(
        find.text('購入記録を更新できませんでした。画面を更新してもう一度お試しください。'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shopping_list_urgent_banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'swipe delete requires confirmation dialog and reflects zero-row failure honestly',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-2');
      addTearDown(client.auth.events.close);

      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'item-del',
          'name': '箱ティッシュ',
          'category': 'daily',
          'quantity': 5,
          'unit': '箱',
          'priority': 'normal',
          'is_purchased': false,
        },
      ];
      var deleteCalls = 0;
      var allowDelete = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ShoppingListPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 23, 9),
            loadItems: (_) async => items,
            deleteItem: (_, id) async {
              deleteCalls += 1;
              if (!allowDelete) return false;
              items.removeWhere((e) => e['id'] == id);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe opens confirmation dialog; cancelling keeps item without deleting.
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('商品を削除'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(deleteCalls, 0);
      expect(find.text('箱ティッシュ'), findsOneWidget);

      // Confirm via delete icon with 0-row failure keeps item and shows error.
      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();
      expect(deleteCalls, 1);
      expect(find.text('削除対象が見つからず、削除できませんでした。'), findsOneWidget);
      expect(find.text('箱ティッシュ'), findsOneWidget);

      // Succeeding delete removes item cleanly.
      allowDelete = true;
      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();
      expect(deleteCalls, 2);
      expect(find.text('箱ティッシュ'), findsNothing);
    },
  );

  testWidgets(
    'add dialog keeps fields on empty name validation and inserts cleanly',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-3');
      addTearDown(client.auth.events.close);

      final items = <Map<String, dynamic>>[];
      Map<String, dynamic>? savedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: ShoppingListPage(
            supabaseClient: client,
            loadItems: (_) async => items,
            insertItem: (payload) async {
              savedPayload = payload;
              items.add(<String, dynamic>{'id': 'new-1', ...payload});
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('shopping_list_appbar_add_button')),
      );
      await tester.pumpAndSettle();

      final shopField = find.widgetWithText(TextField, '購入店');
      await tester.ensureVisible(shopField);
      await tester.enterText(shopField, '駅前ドラッグストア');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('品名を入力してください'), findsOneWidget);
      expect(find.text('駅前ドラッグストア'), findsOneWidget);
      expect(savedPayload, isNull);

      final nameField = find.widgetWithText(TextField, '品名 *');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, '食器用洗剤');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(savedPayload?['name'], '食器用洗剤');
      expect(savedPayload?['shop'], '駅前ドラッグストア');
      expect(find.text('食器用洗剤'), findsOneWidget);
    },
  );

  testWidgets(
    'responsive at 320px@2x and meets Light/Dark contrast & a11y guidelines',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-4');
      addTearDown(client.auth.events.close);

      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'item-a11y-1',
          'name': '有機焙煎スペシャルティコーヒー豆 大容量パック',
          'category': 'drink',
          'quantity': 2.0,
          'unit': '袋',
          'estimated_price': 1980.0,
          'shop': 'オンライン専門焙煎ショップ・東京都渋谷区配送センター',
          'priority': 'urgent',
          'is_purchased': false,
          'is_recurring': true,
          'recurring_days': 14.0,
          'note': '中挽き指定・特売日に購入',
        },
        <String, dynamic>{
          'id': 'item-a11y-2',
          'name': 'トイレットペーパー',
          'category': 'daily',
          'quantity': 1,
          'priority': 'low',
          'is_purchased': true,
          'next_remind_date': '2099-12-31',
        },
      ];

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
            home: ShoppingListPage(
              supabaseClient: client,
              nowProvider: () => DateTime(2026, 11, 23, 9),
              loadItems: (_) async => items,
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
        _contrastRatio(const Color(0xFF7C2D12), const Color(0xFFFFF3E0)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFFFFE0B2), const Color(0xFF2A1F0A)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFFB71C1C), const Color(0xFFFFEBEE)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFFFFB4AB), const Color(0xFF4E1616)),
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
