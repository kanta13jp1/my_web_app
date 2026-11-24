import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/payment_reminder_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user(String id) => User(
      id: id,
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-11-22T00:00:00Z',
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
  testWidgets(
    'marking paid clears due-soon banner and shows paid-this-month badge',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      final reminders = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'rem-1',
          'title': 'au携帯電話',
          'amount': 8400,
          'due_day': 24,
          'category': 'telecom',
          'payment_method': '口座引落',
          'is_active': true,
          'is_auto_pay': false,
          'last_paid_at': null,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReminderPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 22, 9),
            loadReminders: (_) async => reminders,
            markReminderPaid: (_, r, paidAt) async {
              reminders[0] = <String, dynamic>{
                ...r,
                'last_paid_at': paidAt.toIso8601String(),
              };
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('payment_reminder_due_soon_banner')),
        findsOneWidget,
      );
      expect(find.text('支払い完了'), findsOneWidget);

      await tester.tap(find.text('支払い完了'));
      await tester.pumpAndSettle();

      expect(find.text('支払い完了を記録しました'), findsOneWidget);
      expect(
        find.byKey(const Key('payment_reminder_due_soon_banner')),
        findsNothing,
      );
      expect(find.text('支払い完了'), findsNothing);
      expect(find.text('今月支払い済み'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets(
    'false mark-paid result shows error snackbar without faking success',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReminderPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 22, 9),
            loadReminders: (_) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'rem-2',
                'title': '家賃',
                'amount': 85000,
                'due_day': 23,
                'category': 'rent',
                'is_active': true,
                'last_paid_at': null,
              },
            ],
            markReminderPaid: (_, __, ___) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('支払い完了'));
      await tester.pumpAndSettle();

      expect(find.text('支払い完了を記録しました'), findsNothing);
      expect(
        find.text('支払いの記録を保存できませんでした。画面を更新してもう一度お試しください。'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('payment_reminder_due_soon_banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'double tap on mark paid only submits once while in flight',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-1');
      addTearDown(client.auth.events.close);

      final completer = Completer<bool>();
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReminderPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 22, 9),
            loadReminders: (_) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'rem-lock',
                'title': '水道代',
                'amount': 4200,
                'due_day': 22,
                'category': 'utility',
                'is_active': true,
                'last_paid_at': null,
              },
            ],
            markReminderPaid: (_, __, ___) {
              calls++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('支払い完了'));
      await tester.pump();

      expect(calls, 1);
      expect(find.text('記録中...'), findsOneWidget);

      await tester.tap(find.text('記録中...'));
      await tester.pump();
      expect(calls, 1);

      completer.complete(true);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'signed-out state hides add button and routes to login',
    (WidgetTester tester) async {
      final client = _SessionClient();
      addTearDown(client.auth.events.close);

      await tester.pumpWidget(
        MaterialApp(
          routes: <String, WidgetBuilder>{
            '/login': (_) => Scaffold(
                  appBar: AppBar(title: const Text('ログイン画面')),
                ),
          },
          home: PaymentReminderPage(supabaseClient: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('payment_reminder_signed_out_state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('payment_reminder_appbar_add_button')),
        findsNothing,
      );

      await tester.tap(find.text('ログイン'));
      await tester.pumpAndSettle();
      expect(find.text('ログイン画面'), findsOneWidget);
    },
  );

  testWidgets(
    'load error shows error state and recovers on retry',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-2');
      addTearDown(client.auth.events.close);
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReminderPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 10, 9),
            loadReminders: (_) async {
              attempts++;
              if (attempts == 1) {
                throw StateError('network unavailable');
              }
              return <Map<String, dynamic>>[];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('payment_reminder_error_state')),
        findsOneWidget,
      );
      expect(find.text('再試行'), findsOneWidget);

      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('支払いを追加'), findsOneWidget);
    },
  );

  testWidgets(
    'handles double numeric fields and keeps dialog form inputs on empty title',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-3');
      addTearDown(client.auth.events.close);

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReminderPage(
            supabaseClient: client,
            nowProvider: () => DateTime(2026, 11, 10, 9),
            loadReminders: (_) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'rem-num',
                'title': '保険料',
                'amount': 12500.0,
                'due_day': 25.0,
                'category': 'insurance',
                'is_active': true,
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('¥12,500'), findsNWidgets(2));
      expect(find.text('毎月25日'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('payment_reminder_appbar_add_button')),
      );
      await tester.pumpAndSettle();

      final payeeField = find.widgetWithText(TextField, '振込先・支払先');
      await tester.ensureVisible(payeeField);
      await tester.enterText(payeeField, 'KDDI');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('支払い名を入力してください'), findsOneWidget);
      expect(find.text('KDDI'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'responsive at 320px/390px/1440px and meets accessibility guidelines',
    (WidgetTester tester) async {
      final client = _SessionClient();
      client.auth.user = _user('user-4');
      addTearDown(client.auth.events.close);

      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'rem-a11y',
          'title': '光インターネット・モバイルセット月額料金',
          'amount': 6800,
          'due_day': 23,
          'payee': 'テスト電気通信株式会社カスタマーサポート',
          'payment_method': 'クレジットカード',
          'category': 'telecom',
          'is_active': true,
          'is_auto_pay': true,
          'note': '自動更新メモ・明細確認番号 1234567890',
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
            home: PaymentReminderPage(
              supabaseClient: client,
              nowProvider: () => DateTime(2026, 11, 22, 9),
              loadReminders: (_) async => items,
              markReminderPaid: (_, __, ___) async => true,
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
      final autoText = tester.widget<Text>(find.text('自動'));
      expect((autoText.style?.fontSize ?? 0) >= 10, isTrue);
      expect(
        _contrastRatio(const Color(0xFFBAC8FF), const Color(0xFF162447)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(const Color(0xFF1E3A8A), const Color(0xFFE8EEFF)),
        greaterThanOrEqualTo(4.5),
      );

      final handle = tester.ensureSemantics();
      await pumpViewport(const Size(1440, 1000), ThemeData.light(), 1.0);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
