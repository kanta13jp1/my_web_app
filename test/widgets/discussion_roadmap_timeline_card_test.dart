import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/discussion_roadmap_service.dart';
import 'package:my_web_app/widgets/discussion_roadmap_timeline_card.dart';

void main() {
  testWidgets(
      'DiscussionRoadmapTimelineCard renders at 360x800 2.0x scale and logs audits',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = DiscussionRoadmapService(
      now: () => DateTime.utc(2026, 11, 26),
    );
    service.registerMilestone(
      id: 'ms-1',
      topic: '緊急事態条項の起草',
      stage: DiscussionStage.generalDebate,
      targetDate: DateTime.utc(2026, 12, 10),
      ownerGroup: '起草委員会',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DiscussionRoadmapTimelineCard(service: service),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('緊急事態条項の起草'), findsOneWidget);
    expect(find.text('総論討議'), findsWidgets);

    await tester.tap(find.byKey(const Key('roadmap_advance_ms-1')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(service.listMilestones().first.stage, DiscussionStage.drafting);
    expect(service.listAuditHistory().length, 1);

    await tester.tap(find.byKey(const Key('roadmap_delay_ms-1')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(service.listAuditHistory().first.deltaDays, 7);
    expect(find.textContaining('+7日遅延'), findsOneWidget);
  });
}
