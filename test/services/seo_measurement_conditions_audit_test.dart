import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:my_web_app/services/seo_measurement_audit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _JsonMap = Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const auditor = SeoMeasurementAuditService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Issue #5563 seven omitted SEO measurement conditions', () {
    test('1. invalid inputs & anonymous attribution validation reject bad data',
        () {
      final errors = auditor.validateDailyRows([
        {'date': '2026-09-26', 'count': 0},
        {'date': '2026-09-26', 'count': 5},
        {'date': '2026-02-30', 'count': 1},
        {'date': '2026-09-27', 'count': -1},
        {'date': '2026-09-28', 'count': '4'},
        {'date': '2026-09-29', 'count': null},
      ]);
      expect(errors, hasLength(5));

      final validAttr = FirstUserGrowthAttribution.fromUri(
        uri: Uri.parse(
          'https://example.invalid/landing?utm_source=zenn&utm_medium=article&utm_campaign=first_user_growth&utm_content=seo_six',
        ),
        visitorId: '11111111-1111-4111-8111-111111111111',
        capturedAt: DateTime.utc(2026, 9, 27, 0, 0),
      );
      expect(validAttr, isNotNull);

      final badVisitor = FirstUserGrowthAttribution.fromUri(
        uri: Uri.parse(
          'https://example.invalid/landing?utm_source=zenn&utm_campaign=first_user_growth',
        ),
        visitorId: 'user@example.com',
      );
      expect(badVisitor, isNull);
    });

    test('2. timezone boundaries separate UTC vs JST midnight & reject naive',
        () {
      final beforeJstMidnight =
          auditor.resolveUtcAndJstDates('2026-09-26T14:59:59Z');
      final afterJstMidnight =
          auditor.resolveUtcAndJstDates('2026-09-26T15:00:00Z');
      final naive = auditor.resolveUtcAndJstDates('2026-09-26T23:59:59');

      expect(beforeJstMidnight?.utcDate, '2026-09-26');
      expect(beforeJstMidnight?.jstDate, '2026-09-26');
      expect(afterJstMidnight?.utcDate, '2026-09-26');
      expect(afterJstMidnight?.jstDate, '2026-09-27');
      expect(naive, isNull);
    });

    test(
        '3. unrecorded/failed delivery actions do not throw or replay past drops',
        () async {
      final sent = <_JsonMap>[];
      var accepted = 0;
      final transport = MockClient((request) async {
        sent.add(jsonDecode(request.body) as _JsonMap);
        if (sent.length == 1) {
          throw http.ClientException('offline');
        }
        if (sent.length == 2) {
          return http.Response('{"error":"unavailable"}', 503);
        }
        accepted++;
        return http.Response(
          '{"success":true,"recorded":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'https://example.invalid',
        'test-anon-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final service = GrowthAcquisitionService(clientOverride: client);

      await expectLater(
        service.recordTouchpointForPagePath(
          '/landing',
          currentUri: Uri.parse('https://example.invalid/landing'),
        ),
        completes,
      );
      await expectLater(
        service.recordTouchpointForPagePath(
          '/landing',
          currentUri: Uri.parse('https://example.invalid/landing'),
        ),
        completes,
      );
      await expectLater(
        service.recordTouchpointForPagePath(
          '/landing',
          currentUri: Uri.parse('https://example.invalid/landing'),
        ),
        completes,
      );

      expect(sent, hasLength(3));
      expect(accepted, 1);
    });

    test('4. random variation computes two-sided sign test & leave-one-out',
        () {
      final sign = auditor.evaluateSignTest(const [
        SeoMatchedPair(label: 'Mon', beforeCount: 2, afterCount: 4),
        SeoMatchedPair(label: 'Tue', beforeCount: 1, afterCount: 3),
        SeoMatchedPair(label: 'Wed', beforeCount: 3, afterCount: 3),
        SeoMatchedPair(label: 'Thu', beforeCount: 2, afterCount: 5),
        SeoMatchedPair(label: 'Fri', beforeCount: 4, afterCount: 2),
        SeoMatchedPair(label: 'Sat', beforeCount: 1, afterCount: 2),
        SeoMatchedPair(label: 'Sun', beforeCount: 2, afterCount: 3),
      ]);

      expect(sign.nonTiedPairs, 6);
      expect(sign.positiveCount, 5);
      expect(sign.negativeCount, 1);
      expect(sign.twoSidedPValue, greaterThan(0.05));
      expect(sign.leaveOneOutPValues, hasLength(6));
    });

    test(
        '5-7. seasonality caveat, control page rejection & causal rejection without assignment/intervention',
        () {
      expect(
        GrowthAcquisitionService.signalForPagePath('/public-memo'),
        GrowthAcquisitionService.touchPublicMemo,
      );
      expect(
        GrowthAcquisitionService.signalForPagePath('/landing'),
        GrowthAcquisitionService.touchLanding,
      );

      final report = auditor.audit(
        rawDailyRows: const [
          {'date': '2026-09-25', 'count': 4},
          {'date': '2026-09-26', 'count': 6},
        ],
        boundaryTimestamps: const ['2026-09-26T15:00:00Z'],
        attemptedDeliveries: 3,
        acceptedDeliveries: 1,
        matchedPairs: const [
          SeoMatchedPair(label: 'Mon', beforeCount: 2, afterCount: 4),
          SeoMatchedPair(label: 'Tue', beforeCount: 1, afterCount: 3),
        ],
        completeWeeks: 3,
        hasSearchImpressions: false,
        controlBaselineCount: 0,
        controlHasParallelPreTrend: false,
        causalEvidence: const SeoCausalEvidence(
          hasAssignmentRecords: false,
          hasInterventionRecords: false,
          excludesUrlOverrides: false,
          hasFixedCopyVersions: false,
        ),
      );

      expect(report.jstUtcBoundarySplitDetected, isTrue);
      expect(report.unrecordedDeliveryDetected, isTrue);
      expect(report.controlPageValid, isFalse);
      expect(report.causalAttributionAccepted, isFalse);
      expect(
        report.causalRejectionReasons,
        containsAll(<String>[
          'missing_assignment_records',
          'missing_intervention_records',
          'url_overrides_not_excluded',
          'copy_versions_not_frozen',
        ]),
      );
      expect(
        report.conditionStatuses['seasonality_search_demand'],
        SeoAuditConditionStatus.caveated,
      );
      expect(
        report.conditionStatuses['control_pages'],
        SeoAuditConditionStatus.rejected,
      );
      expect(
        report.conditionStatuses['causal_attribution'],
        SeoAuditConditionStatus.rejected,
      );
    });
  });
}
