import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_today_action_section.dart';

void main() {
  const mobileViewport = Size(360, 800);

  Widget wrapMobile2x(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(
        size: mobileViewport,
        textScaler: TextScaler.linear(2.0),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('HomeTodayActionSection @ 360x800 2.0x', () {
    testWidgets('renders normal critical task action with AI nudge & CTA tap',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HomeTodayActionSection(
            actionTypeName: 'criticalTasks',
            accentColor: const Color(0xFF4F46E5),
            icon: Icons.bolt,
            title: '必須タスクを完了する',
            detail: '未完了の必須タスクが3件あります。',
            buttonLabel: '必須タスクへ',
            onPressed: () => tapped++,
            aiNudge: 'まずは1件だけ片付けましょう。',
            pendingCriticalTaskCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(HomeTodayActionSection.headerKey), findsOneWidget);
      expect(
        find.byKey(const Key('home_next_action_criticalTasks')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(HomeTodayActionSection.headerKey),
          matching: find.text('今日の1件'),
        ),
        findsOneWidget,
      );
      expect(find.text('必須タスクを完了する'), findsOneWidget);
      expect(find.text('まずは1件だけ片付けましょう。'), findsOneWidget);

      await tester.ensureVisible(find.text('必須タスクへ'));
      await tester.tap(find.text('必須タスクへ'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('renders loading AI nudge state cleanly', (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMobile2x(
          HomeTodayActionSection(
            actionTypeName: 'morningBriefing',
            accentColor: const Color(0xFF0EA5E9),
            icon: Icons.wb_sunny_outlined,
            title: '朝のブリーフィングを確認する',
            detail: '今日の予定と優先順位を確認します。',
            buttonLabel: 'ブリーフィングへ',
            onPressed: () {},
            isAiNudgeLoading: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(HomeTodayActionSection.headerKey), findsOneWidget);
      expect(
        find.byKey(const Key('home_next_action_morningBriefing')),
        findsOneWidget,
      );
      expect(find.text('朝のブリーフィングを確認する'), findsOneWidget);
    });

    testWidgets('renders empty fallback state and triggers retry CTA',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var refreshed = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HomeTodayActionSection(
            actionTypeName: 'none',
            accentColor: const Color(0xFF64748B),
            icon: Icons.refresh,
            title: '今日の最優先アクションはありません',
            detail: '最新データを取得して再確認できます。',
            buttonLabel: '最新化',
            onPressed: () => refreshed++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_next_action_none')), findsOneWidget);
      await tester.ensureVisible(find.text('最新化'));
      await tester.tap(find.text('最新化'));
      await tester.pump();
      expect(refreshed, 1);
    });
  });
}
