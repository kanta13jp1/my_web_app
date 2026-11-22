import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/feature_requests_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StubClient extends Fake implements SupabaseClient {
  @override
  final GoTrueClient auth = _StubAuth();
}

class _StubAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}

void main() {
  test('pure helpers parse numeric votes safely and format timestamps', () {
    expect(FeatureRequestsPage.safeInt(42), 42);
    expect(FeatureRequestsPage.safeInt(12.0), 12);
    expect(FeatureRequestsPage.safeInt('1,234'), 1234);
    expect(FeatureRequestsPage.safeInt(null), isNull);
    expect(
      FeatureRequestsPage.formatCreatedAt('2026-11-23T01:20:00'),
      '2026/11/23 01:20',
    );
    expect(FeatureRequestsPage.formatCreatedAt(''), '');
  });

  testWidgets(
    'upvote uses RPC return count, prevents double-tap and enforces failure honesty',
    (WidgetTester tester) async {
      final client = _StubClient();
      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'req-1',
          'title': 'キーボードショートカット強化',
          'description': '検索画面をCtrl+Kで開けるようにしたいです。',
          'votes': 4,
          'status': 'open',
          'created_at': '2026-11-23T09:00:00Z',
        },
        <String, dynamic>{
          'id': 'req-closed',
          'title': '終了済みの要望',
          'description': 'すでにクローズされた項目のテストです。',
          'votes': 7,
          'status': 'open',
          'created_at': '2026-11-22T09:00:00Z',
        },
      ];

      final firstGate = Completer<int?>();
      var voteCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FeatureRequestsPage(
            supabaseClient: client,
            loadRequests: () async => items,
            voteRequest: (id) {
              voteCalls += 1;
              if (id == 'req-1') return firstGate.future;
              return Future<int?>.value(null);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final voteBtn =
          find.byKey(const Key('feature_request_vote_button_req-1'));
      await tester.ensureVisible(voteBtn);
      await tester.tap(voteBtn);
      await tester.pump();
      await tester.tap(voteBtn);
      await tester.pump();
      expect(voteCalls, 1);

      firstGate.complete(5);
      await tester.pumpAndSettle();
      expect(find.text('投票済 5'), findsOneWidget);

      // Repeat tap after completion is ignored.
      await tester.tap(voteBtn);
      await tester.pump();
      expect(voteCalls, 1);

      // Null server return keeps vote count unchanged and surfaces honest error.
      final closedBtn =
          find.byKey(const Key('feature_request_vote_button_req-closed'));
      await tester.ensureVisible(closedBtn);
      await tester.tap(closedBtn);
      await tester.pumpAndSettle();
      expect(find.text('投票済 7'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(
        find.text('投票を反映できませんでした（受付終了または対象が見つかりません）。'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'load error surfaces live-region message and recovers cleanly on retry',
    (WidgetTester tester) async {
      final client = _StubClient();
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FeatureRequestsPage(
            supabaseClient: client,
            loadRequests: () async {
              attempts += 1;
              if (attempts == 1) {
                throw StateError('offline');
              }
              return <Map<String, dynamic>>[];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('feature_requests_error_state')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('feature_requests_retry_button')));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(
        find.byKey(const Key('feature_requests_empty_state')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submit dialog validates inline, blocks double-submit and reloads on save',
    (WidgetTester tester) async {
      final client = _StubClient();
      final items = <Map<String, dynamic>>[];
      final submitGate = Completer<void>();
      var submitCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FeatureRequestsPage(
            supabaseClient: client,
            loadRequests: () async => items,
            submitRequest: (title, description) {
              submitCalls += 1;
              items.add(<String, dynamic>{
                'id': 'req-new',
                'title': title,
                'description': description,
                'votes': 1,
                'created_at': '2026-11-23T10:00:00',
              });
              return submitGate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('feature_requests_open_dialog_button')),
      );
      await tester.pumpAndSettle();

      final submitBtn =
          find.byKey(const Key('feature_requests_dialog_submit_button'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('タイトルは3文字以上で入力してください。'), findsOneWidget);
      expect(find.text('詳細は10文字以上で入力してください。'), findsOneWidget);
      expect(submitCalls, 0);

      await tester.enterText(
        find.widgetWithText(TextField, '要望タイトル'),
        'CSVエクスポート対応',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '詳細'),
        '月次データをCSV形式でダウンロードできるようにしてほしいです。',
      );

      await tester.tap(submitBtn);
      await tester.pump();
      expect(find.text('送信中'), findsOneWidget);

      await tester.tap(submitBtn);
      await tester.pump();
      expect(submitCalls, 1);

      submitGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('機能要望を保存しました。'), findsOneWidget);
      expect(find.text('CSVエクスポート対応'), findsOneWidget);
    },
  );

  testWidgets(
    'responsive at 320px@2x with 4-digit votes and meets a11y guidelines',
    (WidgetTester tester) async {
      final client = _StubClient();
      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'req-a11y',
          'title': '非常に長い機能要望タイトルでもモバイル最小幅と拡大表示で折り返されること',
          'description': '長文の説明文がカード幅に収まり、投票ボタンの大きな数字と重ならないことを検証します。',
          'votes': 1234,
          'priority': 'p1',
          'effort': 'm',
          'target_date': '2026-12-01',
          'created_at': '2026-11-23T09:30:00Z',
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
            home: FeatureRequestsPage(
              supabaseClient: client,
              loadRequests: () async => items,
              voteRequest: (_) async => 1235,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpViewport(const Size(320, 568), ThemeData.light(), 2.0);
      expect(find.text('1234'), findsOneWidget);

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
