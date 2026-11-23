import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/competitor_discovery_log_service.dart';
import 'package:my_web_app/widgets/competitor_monitoring_card.dart';

List<Map<String, dynamic>> _sampleRawLogs() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'log-zero-1',
      'discovery_week': '2026-48',
      'run_id': 'run-1001',
      'categories': <String>['productivity', 'fintech'],
      'queries_json': <Map<String, dynamic>>[
        <String, dynamic>{
          'category': 'productivity',
          'prompt_preview': 'Identify 5 trending AI productivity tools...',
          'http_status': 429,
          'candidate_count': 0,
          'response_excerpt': '',
          'error': 'HTTP 429 rate limited',
        },
      ],
      'total_candidates': 0,
      'staged_count': 0,
      'skip_count': 0,
      'error_count': 1,
      'error_logs': <String>['[productivity] HTTP 429 rate limited'],
      'zero_result_alert_triggered': true,
      'alert_summary':
          'Week 2026-48: 0 candidates returned by discovery (errors=1)',
      'created_at': '2026-11-24T00:00:00Z',
    },
    <String, dynamic>{
      'id': 'log-ok-2',
      'discovery_week': '2026-47',
      'run_id': 'run-1000',
      'categories': <String>['ai-coding'],
      'queries_json': <Map<String, dynamic>>[
        <String, dynamic>{
          'category': 'ai-coding',
          'prompt_preview': 'Identify 5 emerging ai-coding platforms...',
          'http_status': 200,
          'candidate_count': 4,
          'response_excerpt': '[{"id":"cursor-clone"}]',
          'error': null,
        },
      ],
      'total_candidates': 4,
      'staged_count': 3,
      'skip_count': 1,
      'error_count': 0,
      'error_logs': <String>[],
      'zero_result_alert_triggered': false,
      'alert_summary': null,
      'created_at': '2026-11-17T00:00:00Z',
    },
  ];
}

void main() {
  group('CompetitorDiscoveryLogService (#2696)', () {
    test('parses rows and filters by zero-alert flag and query keywords',
        () async {
      final service = CompetitorDiscoveryLogService(
        fetcher: ({int limit = 30}) async => _sampleRawLogs(),
      );
      final logs = await service.fetchLogs();
      expect(logs.length, 2);
      expect(logs.first.zeroResultAlertTriggered, isTrue);
      expect(logs.first.queries.first.httpStatus, 429);

      final alertsOnly = CompetitorDiscoveryLogService.filterLogs(
        logs,
        onlyZeroResultAlerts: true,
      );
      expect(alertsOnly.length, 1);
      expect(alertsOnly.first.id, 'log-zero-1');

      final keywordHits = CompetitorDiscoveryLogService.filterLogs(
        logs,
        query: 'ai-coding',
      );
      expect(keywordHits.length, 1);
      expect(keywordHits.first.id, 'log-ok-2');
    });
  });

  group('CompetitorDiscoveryLogsPanel UI & accessibility (#2696)', () {
    testWidgets('searches logs, toggles zero-alert filter, and expands details',
        (tester) async {
      final service = CompetitorDiscoveryLogService(
        fetcher: ({int limit = 30}) async => _sampleRawLogs(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CompetitorDiscoveryLogsPanel(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('competitor_discovery_log_item_log-zero-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('competitor_discovery_log_item_log-ok-2'),
        ),
        findsOneWidget,
      );

      // Filter by zero-alert chip
      await tester.tap(
        find.byKey(
          const ValueKey<String>('competitor_discovery_zero_alert_filter'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('competitor_discovery_log_item_log-zero-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('competitor_discovery_log_item_log-ok-2'),
        ),
        findsNothing,
      );

      // Expand alert log entry to verify query/error details
      await tester.tap(find.text('Week 2026-48'));
      await tester.pumpAndSettle();
      expect(
        find.text('エラー: [productivity] HTTP 429 rate limited'),
        findsOneWidget,
      );

      // Clear filter and test keyword search
      await tester.tap(
        find.byKey(
          const ValueKey<String>('competitor_discovery_zero_alert_filter'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('competitor_discovery_log_search')),
        'ai-coding',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('competitor_discovery_log_item_log-ok-2'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('competitor_discovery_log_item_log-zero-1'),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'passes mobile/desktop 2.0x layout and semantics guidelines in light/dark themes',
        (tester) async {
      final seeded = _sampleRawLogs()
          .map(CompetitorDiscoveryLogEntry.fromJson)
          .toList(growable: false);
      final configs = <(Size, ThemeData)>[
        (const Size(390, 844), ThemeData.light()),
        (const Size(1280, 800), ThemeData.dark()),
      ];
      for (final (viewport, theme) in configs) {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey<String>('${viewport.width}_${theme.brightness}'),
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: CompetitorMonitoringCard(
                      initialDiscoveryLogs: seeded,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(
              const ValueKey<String>('competitor_discovery_logs_panel'),
            ),
            findsOneWidget,
          );

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          handle.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }
    });
  });
}
