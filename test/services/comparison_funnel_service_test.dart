import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/comparison_funnel_service.dart';

void main() {
  group('ComparisonFunnelService', () {
    test('records anonymous stages with sanitized competitorKey and no PII',
        () async {
      final emitted = <Map<String, String>>[];
      final service = ComparisonFunnelService(
        sink: (ComparisonFunnelEvent event) async {
          emitted.add(event.toAnonymousPayload());
        },
      );

      final fixedNow = DateTime.utc(2026, 11, 27, 9, 30);
      expect(
        await service.recordStage(
          competitorKey: 'Notion!@user@example.com',
          stage: ComparisonFunnelStage.comparisonArrival,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        await service.recordStage(
          competitorKey: 'notion',
          stage: ComparisonFunnelStage.comparisonCta,
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        await service.recordStage(
          competitorKey: 'notion',
          stage: ComparisonFunnelStage.registrationCompleted,
          now: fixedNow,
        ),
        isTrue,
      );

      expect(emitted.length, 3);
      expect(emitted[0].keys.toSet(), <String>{
        'competitor_key',
        'stage',
        'date_key',
      });
      expect(emitted[0]['competitor_key'], 'notionuserexamplecom');
      expect(emitted[0]['date_key'], '2026-11-27');
      expect(emitted[1]['stage'], 'comparison_cta');
      expect(emitted[2]['stage'], 'registration_completed');
    });

    test('suppresses all events when optedOut is true', () async {
      var sinkCalled = false;
      final service = ComparisonFunnelService(
        optedOut: true,
        sink: (_) async {
          sinkCalled = true;
        },
      );

      final ok = await service.recordStage(
        competitorKey: 'evernote',
        stage: ComparisonFunnelStage.comparisonArrival,
      );
      expect(ok, isFalse);
      expect(sinkCalled, isFalse);
      expect(service.recordedEvents, isEmpty);
    });

    test('handles sink errors safely without throwing', () async {
      final service = ComparisonFunnelService(
        sink: (_) async {
          throw StateError('network unavailable');
        },
      );

      final ok = await service.recordStage(
        competitorKey: 'slack',
        stage: ComparisonFunnelStage.comparisonCta,
      );
      expect(ok, isFalse);
      expect(service.recordedEvents, isEmpty);
    });

    test('aggregates anonymous funnel conversion rates per competitor',
        () async {
      final service = ComparisonFunnelService();
      await service.recordStage(
        competitorKey: 'notion',
        stage: ComparisonFunnelStage.comparisonArrival,
      );
      await service.recordStage(
        competitorKey: 'notion',
        stage: ComparisonFunnelStage.comparisonArrival,
      );
      await service.recordStage(
        competitorKey: 'notion',
        stage: ComparisonFunnelStage.comparisonCta,
      );
      await service.recordStage(
        competitorKey: 'notion',
        stage: ComparisonFunnelStage.registrationCompleted,
      );

      final summaries = service.aggregateFunnel(service.recordedEvents);
      expect(summaries.length, 1);
      expect(summaries.single.competitorKey, 'notion');
      expect(summaries.single.arrivals, 2);
      expect(summaries.single.ctaClicks, 1);
      expect(summaries.single.registrations, 1);
      expect(summaries.single.ctaRate, closeTo(0.5, 0.0001));
      expect(summaries.single.registrationRate, closeTo(0.5, 0.0001));
    });
  });
}
