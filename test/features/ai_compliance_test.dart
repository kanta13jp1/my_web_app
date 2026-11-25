import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_compliance/ai_compliance_container.dart';
import 'package:my_web_app/features/ai_compliance/application/ai_compliance_controller.dart';
import 'package:my_web_app/features/ai_compliance/domain/ai_compliance_models.dart';

class _FakeAiComplianceRepository implements AiComplianceRepository {
  _FakeAiComplianceRepository({
    final List<AiComplianceRecord>? initialRecords,
  }) : _records = List<AiComplianceRecord>.of(
          initialRecords ?? const <AiComplianceRecord>[],
        );

  final List<AiComplianceRecord> _records;
  int _seq = 1;
  bool shouldFailLoad = false;

  AiComplianceSummary _buildSummary() {
    var unverified = 0;
    var inReview = 0;
    var approved = 0;
    for (final rec in _records) {
      switch (rec.status) {
        case ComplianceVerificationStatus.unverified:
          unverified += 1;
        case ComplianceVerificationStatus.inReview:
          inReview += 1;
        case ComplianceVerificationStatus.approved:
          approved += 1;
      }
    }
    return AiComplianceSummary(
      total: _records.length,
      unverified: unverified,
      inReview: inReview,
      approved: approved,
    );
  }

  @override
  Future<AiComplianceFeedResult> listRecords({
    final String? statusFilter,
    final String? query,
  }) async {
    if (shouldFailLoad) {
      throw StateError('Simulated compliance fetch failure');
    }
    final filtered = _records.where((final rec) {
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter != 'all' &&
          rec.status.wireValue != statusFilter) {
        return false;
      }
      return true;
    }).toList(growable: false);
    return AiComplianceFeedResult(
      records: filtered,
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiComplianceFeedResult> seedDefaults() async {
    if (_records.isEmpty) {
      _records.add(
        const AiComplianceRecord(
          id: 'cmp-seed-1',
          providerKey: 'candidate-frontier-2026q2',
          modelId: 'frontier-reasoner-preview',
          providerName: '新規評価候補A (Q2新興LLM)',
          termsUrl: '',
          reviewNotes: '規約確認前の未検証候補。',
          status: ComplianceVerificationStatus.unverified,
          statusLabel: '未検証',
          checklist: ComplianceChecklistState.empty(),
          approvalNote: '',
          issueDispatchStatus: 'none',
          invokeAllowed: false,
          invokeGuardCode: 'COMPLIANCE_NOT_APPROVED',
        ),
      );
    }
    return AiComplianceFeedResult(
      records: List<AiComplianceRecord>.unmodifiable(_records),
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiComplianceFeedResult> submitReview({
    required final String providerKey,
    required final String modelId,
    required final String providerName,
    final String? termsUrl,
    final String? reviewNotes,
    final ComplianceChecklistState? checklist,
  }) async {
    _seq += 1;
    final created = AiComplianceRecord(
      id: 'cmp-$_seq',
      providerKey: providerKey,
      modelId: modelId,
      providerName: providerName,
      termsUrl: termsUrl ?? '',
      reviewNotes: reviewNotes ?? '',
      status: ComplianceVerificationStatus.inReview,
      statusLabel: '検証中',
      checklist: checklist ?? const ComplianceChecklistState.empty(),
      approvalNote: '',
      githubIssueNumber: 9000 + _seq,
      githubIssueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/9002',
      issueDispatchStatus: 'created',
      invokeAllowed: false,
      invokeGuardCode: 'COMPLIANCE_NOT_APPROVED',
    );
    _records.insert(0, created);
    return AiComplianceFeedResult(
      records: List<AiComplianceRecord>.unmodifiable(_records),
      summary: _buildSummary(),
      highlightedRecord: created,
    );
  }

  @override
  Future<AiComplianceFeedResult> updateChecklist({
    required final String id,
    required final ComplianceChecklistState checklist,
  }) async {
    for (var i = 0; i < _records.length; i += 1) {
      if (_records[i].id == id) {
        final nextStatus =
            _records[i].status == ComplianceVerificationStatus.unverified
                ? ComplianceVerificationStatus.inReview
                : _records[i].status;
        _records[i] = _records[i].copyWith(
          checklist: checklist,
          status: nextStatus,
          statusLabel: nextStatus.labelJa,
        );
      }
    }
    return AiComplianceFeedResult(
      records: List<AiComplianceRecord>.unmodifiable(_records),
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiComplianceFeedResult> approveEntry({
    required final String id,
    required final String reviewerName,
    required final bool humanConfirmed,
    final String? approvalNote,
  }) async {
    if (!humanConfirmed || reviewerName.trim().isEmpty) {
      throw StateError('Human approval required');
    }
    for (var i = 0; i < _records.length; i += 1) {
      if (_records[i].id == id) {
        _records[i] = _records[i].copyWith(
          status: ComplianceVerificationStatus.approved,
          statusLabel: '承認済',
          humanApprovedBy: reviewerName,
          approvedAt: '2026-05-12T00:00:00Z',
          approvalNote: approvalNote ?? '',
          invokeAllowed: true,
          invokeGuardCode: 'COMPLIANCE_APPROVED',
        );
      }
    }
    return AiComplianceFeedResult(
      records: List<AiComplianceRecord>.unmodifiable(_records),
      summary: _buildSummary(),
    );
  }

  @override
  Future<AiComplianceGuardResult> checkInvokeGuard({
    required final String id,
  }) async {
    final target = _records.firstWhere((final r) => r.id == id);
    if (target.status == ComplianceVerificationStatus.approved &&
        (target.humanApprovedBy?.trim().isNotEmpty ?? false) &&
        target.checklist.allComplete) {
      return const AiComplianceGuardResult(
        allowed: true,
        code: 'COMPLIANCE_APPROVED',
        status: ComplianceVerificationStatus.approved,
        reason: '承認済のためAPI呼び出しが許可されています',
      );
    }
    return AiComplianceGuardResult(
      allowed: false,
      code: 'COMPLIANCE_NOT_APPROVED',
      status: target.status,
      reason: 'ステータスが「${target.statusLabel}」のためAPI呼び出しをブロックしました',
    );
  }
}

Widget _buildComplianceApp({
  required final _FakeAiComplianceRepository repository,
  final Brightness brightness = Brightness.light,
  final double textScale = 1.0,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
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
      appBar: AppBar(title: const Text('AIモデル コンプライアンス検証')),
      body: AiComplianceContainer(repository: repository),
    ),
  );
}

void main() {
  test('Compliance models default unknown statuses to unverified', () {
    final res = AiComplianceFeedResult.fromPayload(
      const <String, Object?>{
        'records': <Object?>[
          <String, Object?>{
            'id': 'cmp-1',
            'provider_key': 'new-vendor',
            'model_id': 'model-x',
            'provider_name': 'New Vendor',
            'status': 'invalid_status',
            'invoke_allowed': true,
          },
        ],
      },
    );
    expect(res.records.first.status, ComplianceVerificationStatus.unverified);
    expect(res.records.first.invokeAllowed, isFalse);
  });

  testWidgets('blocks invoke until checklist and human approval complete', (
    final WidgetTester tester,
  ) async {
    final repo = _FakeAiComplianceRepository();
    await tester.pumpWidget(_buildComplianceApp(repository: repo));
    await tester.pumpAndSettle();

    final providerKeyField = find.byKey(
      const ValueKey<String>('ai_compliance_provider_key_field'),
    );
    await tester.ensureVisible(providerKeyField);
    await tester.enterText(providerKeyField, 'vendor-q2');

    final modelIdField = find.byKey(
      const ValueKey<String>('ai_compliance_model_id_field'),
    );
    await tester.ensureVisible(modelIdField);
    await tester.enterText(modelIdField, 'reasoner-2');

    final submitBtn = find.byKey(
      const ValueKey<String>('ai_compliance_submit_btn'),
    );
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('GitHub 法務・セキュリティ確認タスク: #9002'), findsOneWidget);

    final guardBtn = find.byKey(
      const ValueKey<String>('ai_compliance_guard_test_btn'),
    );
    await tester.ensureVisible(guardBtn);
    await tester.tap(guardBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('COMPLIANCE_NOT_APPROVED'), findsWidgets);

    for (final key in const <String>[
      'ai_compliance_check_terms',
      'ai_compliance_check_retention',
      'ai_compliance_check_pii',
      'ai_compliance_check_security',
    ]) {
      final box = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(box);
      await tester.tap(box);
      await tester.pumpAndSettle();
    }

    final reviewerField = find.byKey(
      const ValueKey<String>('ai_compliance_reviewer_field'),
    );
    await tester.ensureVisible(reviewerField);
    await tester.enterText(reviewerField, '法務担当 佐藤');

    final confirmBox = find.byKey(
      const ValueKey<String>('ai_compliance_human_confirm_checkbox'),
    );
    await tester.ensureVisible(confirmBox);
    await tester.tap(confirmBox);
    await tester.pumpAndSettle();

    final approveBtn = find.byKey(
      const ValueKey<String>('ai_compliance_approve_btn'),
    );
    await tester.ensureVisible(approveBtn);
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('承認済'), findsWidgets);

    await tester.ensureVisible(guardBtn);
    await tester.tap(guardBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('COMPLIANCE_APPROVED'), findsWidgets);
  });

  testWidgets('shows error banner and handles controller disposal mid-load', (
    final WidgetTester tester,
  ) async {
    final repo = _FakeAiComplianceRepository()..shouldFailLoad = true;
    final controller = AiComplianceController(repository: repo);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiComplianceContainer(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ai_compliance_error_banner')),
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
    for (final cfg in const <(Brightness, double, Size)>[
      (Brightness.light, 2.0, Size(360, 800)),
      (Brightness.dark, 2.0, Size(360, 800)),
      (Brightness.dark, 2.0, Size(1280, 800)),
    ]) {
      final repo = _FakeAiComplianceRepository();
      await repo.seedDefaults();
      await tester.binding.setSurfaceSize(cfg.$3);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildComplianceApp(
          repository: repo,
          brightness: cfg.$1,
          textScale: cfg.$2,
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
