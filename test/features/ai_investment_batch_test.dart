import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_investment_batch/ai_investment_batch_container.dart';
import 'package:my_web_app/features/ai_investment_batch/application/ai_investment_controller.dart';
import 'package:my_web_app/features/ai_investment_batch/domain/ai_investment_models.dart';

class _FakeAiInvestmentRepository implements AiInvestmentRepository {
  _FakeAiInvestmentRepository({
    final List<AiInvestmentRecord>? initialRecords,
  }) : _records = List<AiInvestmentRecord>.of(
          initialRecords ?? const <AiInvestmentRecord>[],
        );

  final List<AiInvestmentRecord> _records;
  int _seq = 10;
  bool shouldThrowOnLoad = false;

  AiInvestmentSummary _buildSummary() {
    var needs = 0;
    var verified = 0;
    var rejected = 0;
    final quarters = <String>{};
    for (final rec in _records) {
      switch (rec.verificationStatus) {
        case InvestmentVerificationStatus.needsVerification:
          needs += 1;
        case InvestmentVerificationStatus.verified:
          verified += 1;
        case InvestmentVerificationStatus.rejected:
          rejected += 1;
      }
      if (rec.quarter != 'unspecified') {
        quarters.add(rec.quarter);
      }
    }
    return AiInvestmentSummary(
      total: _records.length,
      needsVerification: needs,
      verified: verified,
      rejected: rejected,
      quarters: quarters.toList()..sort(),
    );
  }

  @override
  Future<AiInvestmentFeedResult> listRecords({
    final String? quarter,
    final String? verificationStatus,
    final String? query,
  }) async {
    if (shouldThrowOnLoad) {
      throw StateError('Simulated network error');
    }
    final q = (query ?? '').trim().toLowerCase();
    final filtered = _records.where((final rec) {
      if (quarter != null && quarter.isNotEmpty && rec.quarter != quarter) {
        return false;
      }
      if (verificationStatus != null &&
          verificationStatus.isNotEmpty &&
          verificationStatus != 'all' &&
          rec.verificationStatus.wireValue != verificationStatus) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${rec.companyName} ${rec.roundStage} ${rec.sourceName} ${rec.summary}'
                .toLowerCase();
        if (!hay.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);

    return AiInvestmentFeedResult(
      records: filtered,
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiInvestmentFeedResult> seedDefaults() async {
    if (_records.isEmpty) {
      _records.add(
        const AiInvestmentRecord(
          id: 'seed-1',
          companyName: 'テンプレート例A: フロンティアLLM基盤企業',
          quarter: '2026-Q2',
          roundStage: 'Late Stage (要確認)',
          amountDisplay: '要確認（一次公式発表未入力）',
          currency: 'USD',
          announcedAt: '2026-04-15T00:00:00.000Z',
          sourceName: 'テンプレート初期項目',
          sourceUrl: '',
          investors: <String>['要確認'],
          summary: '初期テンプレート項目。',
          targetProviderCategory: 'フロンティアLLM',
          rawFormat: 'normalized_fallback',
          dedupKey: 'seed-1',
          verificationStatus: InvestmentVerificationStatus.needsVerification,
          verificationLabel: '要検証',
          requiresManualVerification: true,
          verificationNote: '',
          isSampleTemplate: true,
          ingestedAt: '2026-05-01T00:00:00Z',
        ),
      );
    }
    return AiInvestmentFeedResult(
      records: List<AiInvestmentRecord>.unmodifiable(_records),
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiInvestmentIngestResult> ingestPayload({
    required final String rawPayload,
    final String? sourceName,
  }) async {
    _seq += 1;
    final created = AiInvestmentRecord(
      id: 'ing-$_seq',
      companyName: 'Sample Inference Inc',
      quarter: '2026-Q2',
      roundStage: 'Series A',
      amountDisplay: '要一次確認',
      currency: 'USD',
      announcedAt: '2026-05-18T00:00:00Z',
      sourceName: (sourceName != null && sourceName.trim().isNotEmpty)
          ? sourceName.trim()
          : '手動取込フィード',
      sourceUrl: 'https://example.com/press-release',
      investors: const <String>['Test Ventures'],
      summary: 'Ingested payload length=${rawPayload.length}',
      targetProviderCategory: 'LLM / AIインフラ',
      rawFormat: 'structured_json',
      dedupKey: 'sample-inference::2026-q2::series-a',
      verificationStatus: InvestmentVerificationStatus.needsVerification,
      verificationLabel: '要検証',
      requiresManualVerification: true,
      verificationNote: '',
      isSampleTemplate: false,
      ingestedAt: '2026-05-19T00:00:00Z',
    );
    _records.insert(0, created);
    return AiInvestmentIngestResult(
      ingestedCount: 1,
      skippedDuplicates: 0,
      rejectedCount: 0,
      records: List<AiInvestmentRecord>.unmodifiable(_records),
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiInvestmentFeedResult> verifyEntry({
    required final String id,
    required final InvestmentVerificationStatus decision,
    required final String verificationNote,
    final String? sourceUrl,
  }) async {
    for (var i = 0; i < _records.length; i += 1) {
      if (_records[i].id == id) {
        _records[i] = _records[i].copyWith(
          verificationStatus: decision,
          verificationLabel: decision.labelJa,
          requiresManualVerification:
              decision == InvestmentVerificationStatus.needsVerification,
          verificationNote: verificationNote,
          verifiedAt: decision == InvestmentVerificationStatus.needsVerification
              ? null
              : '2026-05-20T00:00:00Z',
          verifiedBy: decision == InvestmentVerificationStatus.needsVerification
              ? null
              : 'tester',
          sourceUrl: sourceUrl,
        );
      }
    }
    return AiInvestmentFeedResult(
      records: List<AiInvestmentRecord>.unmodifiable(_records),
      summary: _buildSummary(),
    );
  }
}

Widget _buildTestApp({
  required final _FakeAiInvestmentRepository repository,
  final Brightness brightness = Brightness.light,
  final double textScale = 1.0,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: brightness,
      ),
    ),
    builder: (final BuildContext context, final Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: Scaffold(
      appBar: AppBar(title: const Text('AI企業投資動向')),
      body: AiInvestmentBatchContainer(repository: repository),
    ),
  );
}

void main() {
  test('AiInvestmentFeedResult enforces needs_verification default on unknown',
      () {
    final result = AiInvestmentFeedResult.fromPayload(
      const <String, Object?>{
        'records': <Object?>[
          <String, Object?>{
            'id': 'rec-1',
            'company_name': 'Example LLM Co',
            'quarter': '2026-Q2',
            'round_stage': 'Series B',
            'amount_display': r'$40M',
            'amount_usd_millions': 40,
            'verification_status': 'unexpected_value',
            'investors': <Object?>['VC Alpha', 'VC Beta'],
          },
        ],
        'summary': <String, Object?>{
          'total': 1,
          'needs_verification': 1,
          'verified': 0,
          'rejected': 0,
          'quarters': <Object?>['2026-Q2'],
        },
      },
    );

    expect(result.records.length, 1);
    final rec = result.records.first;
    expect(rec.companyName, 'Example LLM Co');
    expect(
      rec.verificationStatus,
      InvestmentVerificationStatus.needsVerification,
    );
    expect(rec.verificationLabel, '要検証');
    expect(rec.requiresManualVerification, isTrue);
    expect(rec.amountUsdMillions, 40.0);
    expect(result.summary.total, 1);
    expect(result.summary.quarters, const <String>['2026-Q2']);
  });

  testWidgets('loads empty state, seeds defaults as 要検証, ingests and verifies',
      (
    final WidgetTester tester,
  ) async {
    final repo = _FakeAiInvestmentRepository();
    await tester.pumpWidget(_buildTestApp(repository: repo));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ai_investment_empty_seed_btn')),
      findsOneWidget,
    );

    final seedBtn = find.byKey(
      const ValueKey<String>('ai_investment_seed_btn'),
    );
    await tester.ensureVisible(seedBtn);
    await tester.tap(seedBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('テンプレート例A'), findsWidgets);
    expect(find.text('要検証'), findsWidgets);

    final sampleBtn = find.byKey(
      const ValueKey<String>('ai_investment_insert_sample_btn'),
    );
    await tester.ensureVisible(sampleBtn);
    await tester.tap(sampleBtn);
    await tester.pump();

    final ingestBtn = find.byKey(
      const ValueKey<String>('ai_investment_ingest_submit_btn'),
    );
    await tester.ensureVisible(ingestBtn);
    await tester.tap(ingestBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sample Inference Inc'), findsWidgets);

    final noteField = find.byKey(
      const ValueKey<String>('ai_investment_verify_note_field'),
    );
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, '一次公式プレスリリースにて確認済み');

    final approveBtn = find.byKey(
      const ValueKey<String>('ai_investment_verify_approve_btn'),
    );
    await tester.ensureVisible(approveBtn);
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('確認済み'), findsWidgets);
    expect(find.textContaining('一次公式プレスリリースにて確認済み'), findsWidgets);
  });

  testWidgets('shows load error banner and survives unmount mid-flight', (
    final WidgetTester tester,
  ) async {
    final repo = _FakeAiInvestmentRepository()..shouldThrowOnLoad = true;
    final controller = AiInvestmentController(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiInvestmentBatchContainer(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ai_investment_error_banner')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await controller.loadRecords();
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes a11y guidelines on 360x800 and 1280x800 Light/Dark 2x', (
    final WidgetTester tester,
  ) async {
    for (final config in const <(Brightness, double, Size)>[
      (Brightness.light, 2.0, Size(360, 800)),
      (Brightness.dark, 2.0, Size(360, 800)),
      (Brightness.dark, 2.0, Size(1280, 800)),
    ]) {
      final repo = _FakeAiInvestmentRepository();
      await repo.seedDefaults();
      await tester.binding.setSurfaceSize(config.$3);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildTestApp(
          repository: repo,
          brightness: config.$1,
          textScale: config.$2,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    }
  });
}
