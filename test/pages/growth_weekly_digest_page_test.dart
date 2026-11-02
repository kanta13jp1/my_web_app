import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/growth_weekly_digest_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fixtures/growth_weekly_digest_fixture.dart';

void main() {
  testWidgets(
    'unwraps success digest and renders channels, week, summaries, and decision',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GrowthWeeklyDigestPage(
            loader: () async {
              calls += 1;
              return growthWeeklyDigestSuccessFixture();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('2026-08-23 ～ 2026-08-29'), findsOneWidget);
      expect(find.text('登録送信 1'), findsOneWidget);
      expect(find.text('紹介成立 3'), findsOneWidget);
      expect(find.text('Import CTA 3'), findsOneWidget);
      expect(find.text('公開メモ CTA 2'), findsOneWidget);
      expect(find.text('ランディングページ'), findsWidgets);
      expect(find.text('X profile'), findsWidgets);
      expect(find.text('チャネルデータがありません'), findsNothing);
      expect(find.text('優先チャネル: X profile'), findsOneWidget);
      expect(find.text('期限: 2026-09-05'), findsOneWidget);
      expect(find.textContaining('前週ActionのOutcome: 達成'), findsOneWidget);

      await tester.tap(find.byTooltip('更新'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

  testWidgets('renders a stable authorization error from the envelope', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthWeeklyDigestPage(
          loader: () async => growthWeeklyDigestErrorFixture('admin_required'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('週次ダイジェストの閲覧には管理者権限が必要です'), findsOneWidget);
    expect(find.byKey(const Key('growth-weekly-digest-summary')), findsNothing);
  });

  testWidgets('maps a non-2xx FunctionException to the stable error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthWeeklyDigestPage(
          loader: () async => throw const FunctionException(
            status: 403,
            details: <String, dynamic>{'error': 'admin_required'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('週次ダイジェストの閲覧には管理者権限が必要です'), findsOneWidget);
  });
}
