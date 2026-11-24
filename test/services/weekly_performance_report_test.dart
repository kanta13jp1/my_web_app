import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/weekly_performance_report_service.dart';
import 'package:my_web_app/widgets/weekly_performance_report_panel.dart';

void main() {
  group('WeeklyReportPrivacyEvaluator', () {
    test(
      'masks emails, phones, and bearer tokens before preview or dispatch',
      () {
        const String fakeBearer = 'Bearer tok_' 'xyz_9988';
        const String raw =
            '担当 alice@example.com / TEL 090-1234-5678 / $fakeBearer';
        final String masked =
            WeeklyReportPrivacyEvaluator.redactPiiForPreview(raw);

        expect(masked, isNot(contains('alice@example.com')));
        expect(masked, isNot(contains('090-1234-5678')));
        expect(masked, isNot(contains(fakeBearer)));
        expect(masked, contains('[REDACTED_EMAIL]'));
        expect(masked, contains('[REDACTED_PHONE]'));
        expect(masked, contains('[REDACTED_TOKEN]'));
      },
    );
  });

  group('WeeklyPerformanceReportService', () {
    test(
      'generates PII-redacted dry-run preview, handles delivery runner, and disposes safely',
      () async {
        bool failNext = false;
        final WeeklyPerformanceReportService service =
            WeeklyPerformanceReportService(
          nowProvider: () => DateTime.utc(2026, 11, 24, 9),
          deliveryRunner: (
            WeeklyPerformanceReport report,
            bool dryRun,
          ) async {
            if (failNext) {
              throw StateError('mail api down');
            }
            return dryRun
                ? WeeklyDeliveryStatus.dryRun
                : WeeklyDeliveryStatus.sent;
          },
        );
        addTearDown(service.dispose);

        await service.loadReports();
        expect(service.latestReport, isNotNull);
        expect(service.latestReport!.piiRedacted, isTrue);

        final WeeklyPerformanceReport preview =
            await service.generateDryRunPreview(
          contextNote: '通知先 founder@example.com へ週次サマリー検証',
        );
        expect(preview.insightMarkdown, isNot(contains('founder@example.com')));
        expect(preview.insightMarkdown, contains('[REDACTED_EMAIL]'));

        expect(await service.triggerDelivery(dryRun: false), isTrue);
        expect(service.latestReport!.deliveryStatus, WeeklyDeliveryStatus.sent);

        failNext = true;
        expect(await service.triggerDelivery(dryRun: false), isFalse);
        expect(
          service.latestReport!.deliveryStatus,
          WeeklyDeliveryStatus.failed,
        );

        service.dispose();
        service.dispose();
      },
    );
  });

  group('WeeklyPerformanceReportPanel', () {
    testWidgets(
      'masks PII on dry-run preview and triggers delivery cleanly',
      (WidgetTester tester) async {
        const WeeklyDeliveryStatus requestedOutcome = WeeklyDeliveryStatus.sent;
        final WeeklyPerformanceReportService service =
            WeeklyPerformanceReportService(
          nowProvider: () => DateTime.utc(2026, 11, 24, 9),
          deliveryRunner: (
            WeeklyPerformanceReport report,
            bool dryRun,
          ) async {
            return requestedOutcome;
          },
        );
        addTearDown(service.dispose);
        await service.loadReports();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: WeeklyPerformanceReportPanel(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PII匿名化済み'), findsOneWidget);

        final Finder noteField = find.byKey(
          const ValueKey<String>('weekly-report-note-field'),
        );
        await tester.ensureVisible(noteField);
        await tester.pumpAndSettle();
        await tester.enterText(noteField, '連絡 user@example.com 確認済み');

        final Finder dryRunBtn = find.byKey(
          const ValueKey<String>('weekly-report-dryrun-button'),
        );
        await tester.ensureVisible(dryRunBtn);
        await tester.pumpAndSettle();
        await tester.tap(dryRunBtn);
        await tester.pumpAndSettle();

        expect(
          service.latestReport!.insightMarkdown,
          contains('[REDACTED_EMAIL]'),
        );
        expect(
          service.latestReport!.insightMarkdown,
          isNot(contains('user@example.com')),
        );

        final Finder sendBtn = find.byKey(
          const ValueKey<String>('weekly-report-send-button'),
        );
        await tester.ensureVisible(sendBtn);
        await tester.pumpAndSettle();
        await tester.tap(sendBtn);
        await tester.pumpAndSettle();

        expect(find.text('配信完了'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit at 360x800 and 1280x800 in light/dark modes with 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(360, 800),
          Size(1280, 800),
        ];
        const List<Brightness> modes = <Brightness>[
          Brightness.light,
          Brightness.dark,
        ];

        for (final Size viewport in viewports) {
          for (final Brightness mode in modes) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            final WeeklyPerformanceReportService service =
                WeeklyPerformanceReportService(
              nowProvider: () => DateTime.utc(2026, 11, 24, 9),
            );
            await service.loadReports();

            final SemanticsHandle semanticsHandle = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>('${viewport.width}_${mode.name}'),
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: mode,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF1E3A8A),
                      brightness: mode,
                    ),
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: viewport,
                      textScaler: const TextScaler.linear(2.0),
                    ),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: WeeklyPerformanceReportPanel(service: service),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              service.dispose();
            }
          }
        }
      },
    );
  });
}
