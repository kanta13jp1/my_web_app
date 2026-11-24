import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/quota_pause_service.dart';
import 'package:my_web_app/widgets/quota_auto_pause_banner.dart';

class _FakeQuotaPauseRepository implements QuotaPauseRepository {
  _FakeQuotaPauseRepository({
    required List<QuotaPauseStateItem> seed,
  }) : items = List<QuotaPauseStateItem>.from(seed);

  final List<QuotaPauseStateItem> items;
  bool shouldThrowOnList = false;

  @override
  Future<List<QuotaPauseStateItem>> listPauseStates() async {
    if (shouldThrowOnList) {
      throw StateError('simulated list failure');
    }
    return items.toList(growable: false);
  }

  @override
  Future<QuotaPauseStateItem> resumeTool({
    required String tool,
    String adminNote = '',
  }) async {
    final idx = items.indexWhere((entry) => entry.tool == tool);
    final cur = items[idx];
    final updated = QuotaPauseStateItem(
      tool: cur.tool,
      usagePct: cur.usagePct,
      warning80Sent: cur.warning80Sent,
      warning80SentAt: cur.warning80SentAt,
      autoPaused: false,
      pausedAt: cur.pausedAt,
      silentPauseDetected: cur.silentPauseDetected,
      resumedByAdmin: true,
      resumedAt: DateTime.utc(2026, 11, 24, 3),
      adminIssueNumber: cur.adminIssueNumber,
      adminNote: adminNote,
      updatedAt: DateTime.utc(2026, 11, 24, 3),
    );
    items[idx] = updated;
    return updated;
  }
}

List<QuotaPauseStateItem> _samplePauseStates() => <QuotaPauseStateItem>[
      QuotaPauseStateItem(
        tool: 'openai',
        usagePct: 102.5,
        warning80Sent: true,
        autoPaused: true,
        silentPauseDetected: true,
        resumedByAdmin: false,
        adminIssueNumber: 9001,
        pausedAt: DateTime.utc(2026, 11, 24),
      ),
      const QuotaPauseStateItem(
        tool: 'anthropic',
        usagePct: 84.0,
        warning80Sent: true,
        autoPaused: false,
        silentPauseDetected: false,
        resumedByAdmin: false,
      ),
      const QuotaPauseStateItem(
        tool: 'actions_minutes',
        usagePct: 45.0,
        warning80Sent: false,
        autoPaused: false,
        silentPauseDetected: false,
        resumedByAdmin: false,
      ),
    ];

void main() {
  group('QuotaPauseService (#2612)', () {
    test(
      'parses JSON states, computes threshold tiers, and initializes repo lazily',
      () {
        final repo = SupabaseQuotaPauseRepository();
        expect(repo, isNotNull);

        final parsed = QuotaPauseStateItem.fromJson(
          const <String, Object?>{
            'tool': 'OpenAI',
            'usage_pct': '100.0',
            'warning_80_sent': true,
            'auto_paused': true,
            'silent_pause_detected': true,
            'resumed_by_admin': false,
            'admin_issue_number': 77,
          },
        );
        expect(parsed.tool, 'openai');
        expect(parsed.tier, QuotaThresholdTier.paused100);
        expect(parsed.isEffectivePaused, isTrue);
        expect(parsed.silentPauseDetected, isTrue);
        expect(parsed.adminIssueNumber, 77);

        final summary = QuotaThresholdSummary.fromItems(_samplePauseStates());
        expect(summary.totalCount, 3);
        expect(summary.normalCount, 1);
        expect(summary.warning80Count, 1);
        expect(summary.paused100Count, 1);
        expect(summary.silentPauseCount, 1);
        expect(summary.hasAnyAlert, isTrue);
      },
    );
  });

  group('QuotaAutoPauseBanner UI & accessibility (#2612)', () {
    testWidgets(
      'displays 80%/100%/silent-pause alerts, resumes tool by admin, and shows errors',
      (tester) async {
        final repo = _FakeQuotaPauseRepository(seed: _samplePauseStates());

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: QuotaAutoPauseBanner(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('quota_kpi_warning80')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('quota_kpi_paused100')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('quota_silent_pause_openai')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('quota_resume_btn_openai')),
          findsOneWidget,
        );

        final noteInput =
            find.byKey(const ValueKey<String>('quota_admin_note_input'));
        await tester.ensureVisible(noteInput);
        await tester.pumpAndSettle();
        await tester.enterText(noteInput, '課金上限を引き上げ済み');

        final resumeBtn =
            find.byKey(const ValueKey<String>('quota_resume_btn_openai'));
        await tester.ensureVisible(resumeBtn);
        await tester.pumpAndSettle();
        await tester.tap(resumeBtn);
        await tester.pumpAndSettle();

        expect(repo.items.first.autoPaused, isFalse);
        expect(repo.items.first.resumedByAdmin, isTrue);
        expect(repo.items.first.adminNote, '課金上限を引き上げ済み');

        repo.shouldThrowOnList = true;
        final refreshBtn =
            find.byKey(const ValueKey<String>('quota_pause_refresh_btn'));
        await tester.ensureVisible(refreshBtn);
        await tester.pumpAndSettle();
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('quota_pause_error_banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'meets light/dark 390x844 and 1280x800 layout with 2.0x textScale and accessibility guidelines',
      (tester) async {
        final seeded = _samplePauseStates();
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
                key: ValueKey<String>(
                  '${viewport.width}_${theme.brightness}',
                ),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: QuotaAutoPauseBanner(initialStates: seeded),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey<String>('quota_auto_pause_banner')),
              findsOneWidget,
            );

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(textContrastGuideline),
            );
          } finally {
            handle.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        }
      },
    );
  });
}
