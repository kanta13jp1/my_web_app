import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/philosophy_page.dart';
import 'package:my_web_app/services/philosophy_funnel_analytics.dart';
import 'package:my_web_app/utils/route_document_title.dart';

void main() {
  testWidgets('philosophy page explains the self-management operating model', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: PhilosophyPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('自分株式会社を30日で運営する実践ガイド'), findsOneWidget);
    expect(find.text('個人の P/L・B/S'), findsOneWidget);
    expect(find.text('人生を6部署に分けて点検する'), findsOneWidget);
    expect(find.text('30日の運営サイクル'), findsOneWidget);
    expect(find.text('AIはCEOの代わりではなく伴走役'), findsOneWidget);
    expect(find.text('3分でできる棚卸しの記入例'), findsOneWidget);
    expect(find.text('架空ケース：30日でどう見直すか'), findsOneWidget);
    expect(find.text('この例で選ぶ「今月の1件」'), findsOneWidget);
    expect(find.text('このページの編集方針'), findsOneWidget);
    expect(find.textContaining('実在する利用者の体験談や成果ではありません'), findsOneWidget);
    expect(find.text('開発実績と更新履歴'), findsOneWidget);
    expect(find.text('GitHub @kanta13jp1'), findsOneWidget);
    expect(find.text('データの取り扱い'), findsOneWidget);
    expect(find.text('本社'), findsOneWidget);
    expect(find.text('人事'), findsOneWidget);
    expect(find.text('R&D'), findsOneWidget);
    expect(find.text('財務'), findsOneWidget);
    expect(find.text('マーケ営業'), findsOneWidget);
    expect(find.text('横断'), findsOneWidget);
    final documentTitle = find.byKey(const Key('philosophy_document_title'));
    expect(documentTitle, findsOneWidget);
    expect(tester.widget<Title>(documentTitle).title, philosophyDocumentTitle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('philosophy inventory example stays readable on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: PhilosophyPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.scrollUntilVisible(
      find.text('3分でできる棚卸しの記入例').first,
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('本社｜今月の方針'), findsOneWidget);
    expect(find.text('人事｜土台'), findsOneWidget);
    expect(find.text('4週目｜配分を直す'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('philosophy CTA completes the measured quick inventory', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final analytics = _RecordingPhilosophyAnalytics();

    await tester.pumpWidget(
      MaterialApp(
        home: PhilosophyPage(analytics: analytics),
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/philosophy');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PhilosophyPage(
              analytics: analytics,
              initialStep: uri.queryParameters['step'] == 'quick-inventory'
                  ? PhilosophyInitialStep.quickInventory
                  : PhilosophyInitialStep.overview,
            ),
          );
        },
      ),
    );
    await tester.pump();

    expect(find.textContaining('番外:'), findsNothing);
    expect(
      find.byKey(const Key('philosophy_ai_university_video_link')),
      findsOneWidget,
    );

    final cta = find.byKey(const Key('philosophy_start_quick_inventory'));
    await tester.scrollUntilVisible(
      cta,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('philosophy_quick_inventory')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('philosophy_department_finance')),
    );
    await tester.tap(
      find.byKey(const Key('philosophy_action_start_one')),
    );
    await tester.tap(
      find.byKey(const Key('philosophy_complete_first_action')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('philosophy_first_action_completed')),
      findsOneWidget,
    );
    final feedback = find.byKey(const Key('philosophy_feedback_helpful'));
    await tester.scrollUntilVisible(
      feedback,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(feedback);
    await tester.tap(
      find.byKey(const Key('philosophy_submit_feedback')),
    );
    await tester.pump();

    expect(
      analytics.events.map((event) => event.stage),
      containsAllInOrder(<PhilosophyFunnelStage>[
        PhilosophyFunnelStage.pageView,
        PhilosophyFunnelStage.ctaClick,
        PhilosophyFunnelStage.pageView,
        PhilosophyFunnelStage.quickInventoryView,
        PhilosophyFunnelStage.firstActionComplete,
        PhilosophyFunnelStage.feedback,
      ]),
    );
    final completed = analytics.events.firstWhere(
      (event) => event.stage == PhilosophyFunnelStage.firstActionComplete,
    );
    expect(completed.safeProperties['department_id'], 'finance');
    expect(completed.safeProperties['action_id'], 'start_one');
  });
}

class _RecordingPhilosophyAnalytics implements PhilosophyFunnelAnalytics {
  final List<PhilosophyFunnelEvent> events = <PhilosophyFunnelEvent>[];

  @override
  Future<void> capture(PhilosophyFunnelEvent event) async {
    events.add(event);
  }
}
