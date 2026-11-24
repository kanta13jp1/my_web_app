import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/content_moderation_ticket_service.dart';
import 'package:my_web_app/widgets/moderation_ticket_panel.dart';

void main() {
  group('ModerationPolicyEvaluator & ContentModerationTicketService', () {
    test('classifies severity deterministically and enforces open payload', () {
      expect(
        ModerationPolicyEvaluator.classifySeverity(
          category: ModerationViolationCategory.illegalContent,
          reasonText: '違法ファイルの共有',
        ),
        ModerationSeverity.urgent,
      );
      expect(
        ModerationPolicyEvaluator.classifySeverity(
          category: ModerationViolationCategory.harassment,
          reasonText: '殺害を示唆する脅迫コメント',
        ),
        ModerationSeverity.urgent,
      );
      expect(
        ModerationPolicyEvaluator.classifySeverity(
          category: ModerationViolationCategory.spam,
          reasonText: '連投コメント',
        ),
        ModerationSeverity.low,
      );

      final ModerationTicket ticket = ModerationTicket.fromJson(
        const <String, Object?>{
          'id': 'mod-1',
          'target_entity_type': 'public_memo',
          'target_entity_id': 'memo-9',
          'violation_category': 'privacy_violation',
          'severity': 'high',
          'report_reason': '住所と電話番号が含まれている',
        },
      );
      expect(ticket.ticketStatus, ModerationTicketStatus.open);
      expect(ticket.assignedModeratorId, isNull);
      expect(ticket.resolutionNote, isNull);
      final Map<String, Object?> payload = ticket.toInsertPayload('user-1');
      expect(payload['ticket_status'], 'open');
      expect(payload.containsKey('assigned_moderator_id'), isFalse);
      expect(payload.containsKey('resolution_note'), isFalse);
    });

    test(
        'validates transitions and requires resolution_note on resolve/dismiss',
        () async {
      final ContentModerationTicketService service =
          ContentModerationTicketService(
        initialTickets: const <ModerationTicket>[
          ModerationTicket(
            id: 't-100',
            targetEntityType: 'public_memo',
            targetEntityId: 'memo-100',
            violationCategory: ModerationViolationCategory.spam,
            severity: ModerationSeverity.low,
            reportReason: '宣伝URLの連続投稿',
          ),
        ],
      );

      final bool missingNote = await service.transitionTicketStatus(
        ticketId: 't-100',
        nextStatus: ModerationTicketStatus.resolved,
      );
      expect(missingNote, isFalse);
      expect(service.validationErrors, isNotEmpty);
      expect(
        service.allTickets.first.ticketStatus,
        ModerationTicketStatus.open,
      );

      final bool started = await service.transitionTicketStatus(
        ticketId: 't-100',
        nextStatus: ModerationTicketStatus.inReview,
        moderatorId: 'mod-admin',
      );
      expect(started, isTrue);
      expect(
        service.allTickets.first.ticketStatus,
        ModerationTicketStatus.inReview,
      );

      final bool resolved = await service.transitionTicketStatus(
        ticketId: 't-100',
        nextStatus: ModerationTicketStatus.resolved,
        moderatorId: 'mod-admin',
        resolutionNote: 'スパム基準に基づき非公開化を実施',
      );
      expect(resolved, isTrue);
      expect(
        service.allTickets.first.ticketStatus,
        ModerationTicketStatus.resolved,
      );
      expect(
        service.allTickets.first.resolutionNote,
        'スパム基準に基づき非公開化を実施',
      );
      expect(service.allTickets.first.resolvedAtIso, isNotNull);

      final bool reopened = await service.transitionTicketStatus(
        ticketId: 't-100',
        nextStatus: ModerationTicketStatus.inReview,
        moderatorId: 'mod-admin',
      );
      expect(reopened, isTrue);
      expect(
        service.allTickets.first.ticketStatus,
        ModerationTicketStatus.inReview,
      );
      expect(service.allTickets.first.resolvedAtIso, isNull);
    });
  });

  group('ModerationTicketPanel', () {
    testWidgets(
        'submits report as open, filters queue, and handles moderator transitions',
        (
      WidgetTester tester,
    ) async {
      final ContentModerationTicketService service =
          ContentModerationTicketService();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF1E40AF)),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ModerationTicketPanel(
                service: service,
                isModeratorMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder submitButton = find.byKey(
        const ValueKey<String>('moderation-submit-button'),
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('moderation-validation-errors')),
        findsOneWidget,
      );

      final Finder entityIdField = find.byKey(
        const ValueKey<String>('moderation-entity-id-field'),
      );
      await tester.ensureVisible(entityIdField);
      await tester.pumpAndSettle();
      await tester.enterText(entityIdField, 'memo-404');

      final Finder reasonField = find.byKey(
        const ValueKey<String>('moderation-reason-field'),
      );
      await tester.ensureVisible(reasonField);
      await tester.pumpAndSettle();
      await tester.enterText(reasonField, '個人情報（住所）の無断掲載');

      final Finder privacyChip = find.byKey(
        const ValueKey<String>('moderation-category-privacy_violation'),
      );
      await tester.ensureVisible(privacyChip);
      await tester.pumpAndSettle();
      await tester.tap(privacyChip);
      await tester.pumpAndSettle();

      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(service.allTickets.length, 1);
      final String createdId = service.allTickets.first.id;
      expect(
        service.allTickets.first.ticketStatus,
        ModerationTicketStatus.open,
      );
      expect(service.allTickets.first.severity, ModerationSeverity.high);
      expect(find.text('public_memo: memo-404'), findsOneWidget);

      final Finder resolutionField = find.byKey(
        const ValueKey<String>('moderation-resolution-field'),
      );
      await tester.ensureVisible(resolutionField);
      await tester.pumpAndSettle();
      await tester.enterText(resolutionField, 'プライバシー保護基準により非公開化');

      final Finder resolveButton = find.byKey(
        ValueKey<String>('moderation-resolve-$createdId'),
      );
      await tester.ensureVisible(resolveButton);
      await tester.pumpAndSettle();
      await tester.tap(resolveButton);
      await tester.pumpAndSettle();

      expect(
        service.allTickets.first.ticketStatus,
        ModerationTicketStatus.resolved,
      );
      expect(find.textContaining('プライバシー保護基準により非公開化'), findsOneWidget);

      final Finder openFilterChip = find.byKey(
        const ValueKey<String>('moderation-filter-open'),
      );
      await tester.ensureVisible(openFilterChip);
      await tester.pumpAndSettle();
      await tester.tap(openFilterChip);
      await tester.pumpAndSettle();
      expect(find.text('public_memo: memo-404'), findsNothing);

      final Finder resolvedFilterChip = find.byKey(
        const ValueKey<String>('moderation-filter-resolved'),
      );
      await tester.ensureVisible(resolvedFilterChip);
      await tester.pumpAndSettle();
      await tester.tap(resolvedFilterChip);
      await tester.pumpAndSettle();
      expect(find.text('public_memo: memo-404'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'passes responsive and WCAG accessibility audit in light and dark modes at 2.0x textScale',
        (
      WidgetTester tester,
    ) async {
      const List<Size> viewports = <Size>[Size(390, 844), Size(1280, 800)];
      const List<Brightness> modes = <Brightness>[
        Brightness.light,
        Brightness.dark,
      ];

      for (final Size viewport in viewports) {
        for (final Brightness mode in modes) {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          final ContentModerationTicketService service =
              ContentModerationTicketService(
            initialTickets: const <ModerationTicket>[
              ModerationTicket(
                id: 'audit-1',
                targetEntityType: 'public_memo',
                targetEntityId: 'memo-99',
                violationCategory: ModerationViolationCategory.privacyViolation,
                severity: ModerationSeverity.high,
                reportReason: '個人情報を含むメモの報告テスト',
              ),
            ],
          );

          final SemanticsHandle semanticsHandle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey<String>('${viewport.width}_${mode.name}'),
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: mode,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF1E40AF),
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
                      child: ModerationTicketPanel(
                        service: service,
                        isModeratorMode: true,
                      ),
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
          }
        }
      }
    });
  });
}
