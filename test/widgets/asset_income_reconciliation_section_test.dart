import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_income_source_evidence.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/widgets/asset_income_reconciliation_section.dart';

IncomeEvidenceProjection sample() => AssetSalarySpendingEntries.projectCycle(
      ownerId: 'synthetic',
      flowOwnerId: 'synthetic',
      financeOwnerId: 'synthetic',
      reference: DateTime(2026, 6, 20),
      salaryDay: 25,
      recentFlows: const [
        {
          'id': 'f1',
          'action_type': 'conquer',
          'occurred_at': '2026-06-20',
          'amount': 100,
        }
      ],
      payslipSalaryIncomes: const [
        {'id': 's1', 'pay_date': '2026-06-20', 'amount': 100},
      ],
      payslipRows: const [],
      monthlyIncomePlans: const [],
    );

void main() {
  test('unavailable income explanations distinguish empty, pending, failed, limit and unresolved', () {
    final empty = AssetIncomeSourceEvidence.project(ownerId: 'synthetic', currency: 'JPY', records: const [],);
    expect(AssetIncomeReconciliationSection.unavailableReason(empty, reading: false), contains('根拠となる収入記録がない'));
    expect(AssetIncomeReconciliationSection.unavailableReason(empty, reading: false), contains('0円と確定した値ではありません'));
    final failed = withholdIncomeEvidence(sample());
    expect(AssetIncomeReconciliationSection.unavailableReason(failed, reading: false), contains('読み取りを確認できない'));
    final limited = withholdIncomeEvidence(sample(), reason: IncomeEvidenceProblem.readLimitReached);
    expect(AssetIncomeReconciliationSection.unavailableReason(limited, reading: false), contains('取得範囲に上限'));
    expect(AssetIncomeReconciliationSection.unavailableReason(limited, reading: true), '収入の記録を読み取り中のため未計算です。');
    expect(AssetIncomeReconciliationSection.unavailableReason(sample(), reading: false), contains('出典間の対応が未照合'));
    for (final value in [empty, failed, limited, sample()]) {
      expect(AssetIncomeReconciliationSection.unavailableReason(value, reading: false), isNot(contains('重複')));
      expect(value.combinedRecordedTotal, isNull);
    }
  });
  for (final same in [true, false]) {
    testWidgets('confirmation is required before memory decision same=$same',
        (tester) async {
      var decisions = 0;
      IncomeRelationship? result;
      var clears = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetIncomeReconciliationSection(
                projection: sample(),
                busy: false,
                onReload: () {},
                onDecision: (left, right, relationship) {
                  decisions++;
                  result = relationship;
                },
                onClear: () {
                  clears++;
                },
                onPage: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('収入の照合が必要'));
      await tester.pumpAndSettle();
      final button = find.text(same ? '同じ収入として照合' : '別件として照合');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(decisions, 0);
      expect(find.textContaining('この画面内の記録集計にだけ反映'), findsOneWidget);
      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      expect(decisions, 0);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('この画面で照合する'));
      await tester.pumpAndSettle();
      expect(decisions, 1);
      expect(
        result,
        same ? IncomeRelationship.sameEvent : IncomeRelationship.distinctEvents,
      );
      await tester.ensureVisible(find.text('この画面の照合を取り消す'));
      await tester.tap(find.text('この画面の照合を取り消す'));
      expect(clears, 1);
    });
  }
  testWidgets(
      'failed or limited read explains withheld total, disables decisions, permits retry at narrow width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final problem in [
      IncomeEvidenceProblem.readUnconfirmed,
      IncomeEvidenceProblem.readLimitReached,
    ]) {
      var reloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetIncomeReconciliationSection(
                key: ValueKey(problem),
                projection: withholdIncomeEvidence(sample(), reason: problem),
                busy: false,
                onReload: () {
                  reloads++;
                },
                onDecision: (left, right, relationship) =>
                    fail('unconfirmed read must not permit decisions'),
                onClear: () {},
                onPage: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('収入の照合が必要'));
      await tester.pumpAndSettle();
      expect(
        find.text(AssetIncomeReconciliationSection.issueLabel(problem)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '同じ収入として照合'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '別件として照合'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('既存明細を再読込'));
      await tester.tap(find.text('既存明細を再読込'));
      expect(reloads, 1);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
      'bounded relationship page exposes navigation without silently dropping pairs',
      (tester) async {
    final value = AssetSalarySpendingEntries.projectCycle(
      ownerId: 'synthetic',
      flowOwnerId: 'synthetic',
      financeOwnerId: 'synthetic',
      reference: DateTime(2026, 6, 20),
      salaryDay: 25,
      recentFlows: List.generate(
        8,
        (i) => {
          'id': 'f$i',
          'action_type': 'conquer',
          'occurred_at': '2026-06-20',
          'amount': 100,
        },
      ),
      payslipSalaryIncomes: List.generate(
        8,
        (i) => {'id': 's$i', 'pay_date': '2026-06-20', 'amount': 100},
      ),
      payslipRows: const [],
      monthlyIncomePlans: const [],
    );
    expect(value.unresolvedRelationshipCount, greaterThan(20));
    expect(
      value.issues.where(
        (i) => i.problem == IncomeEvidenceProblem.missingRelationship,
      ),
      hasLength(20),
    );
    int? page;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetIncomeReconciliationSection(
              projection: value,
              busy: false,
              onReload: () {},
              onDecision: (left, right, relationship) {},
              onClear: () {},
              onPage: (next) {
                page = next;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('収入の照合が必要'));
    await tester.pumpAndSettle();
    final next = find.text('次の照合対象');
    await tester.ensureVisible(next);
    await tester.tap(next);
    expect(page, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '前の照合対象'))
          .onPressed,
      isNull,
    );
  });
  testWidgets(
      'existing FK, temporary confirmation and monetary conflict have distinct status',
      (tester) async {
    Future<void> mount(
      IncomeEvidenceProjection value, {
      int memoryCount = 0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetIncomeReconciliationSection(
                key: ValueKey(value),
                projection: value,
                memoryDecisionCount: memoryCount,
                busy: false,
                onReload: () {},
                onDecision: (left, right, relationship) {},
                onClear: () {},
                onPage: (page) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.text(
          value.combinedRecordedTotal == null ? '収入の照合が必要' : '記録上の収入を照合済み',
        ),
      );
      await tester.pumpAndSettle();
    }

    IncomeEvidenceProjection linked(int amount) =>
        AssetSalarySpendingEntries.projectCycle(
          ownerId: 'synthetic',
          flowOwnerId: 'synthetic',
          financeOwnerId: 'synthetic',
          reference: DateTime(2026, 6, 20),
          salaryDay: 25,
          recentFlows: const [],
          monthlyIncomePlans: const [],
          payslipSalaryIncomes: const [
            {
              'id': 's1',
              'payslip_id': 'p1',
              'pay_date': '2026-06-20',
              'amount': 100,
            }
          ],
          payslipRows: [
            {
              'id': 'p1',
              'pay_date': '2026-06-20',
              'net_amount': amount,
            }
          ],
        );
    await mount(linked(100));
    expect(find.text('既存明細IDで照合'), findsOneWidget);
    expect(find.textContaining('この画面で本人確認・未保存'), findsNothing);
    final raw = sample();
    final decision = IncomeRelationshipDecision(
      leftFingerprint: raw.records[0].fingerprint,
      rightFingerprint: raw.records[1].fingerprint,
      relationship: IncomeRelationship.sameEvent,
    );
    final manual = AssetIncomeSourceEvidence.project(
      ownerId: 'synthetic',
      currency: 'JPY',
      records: raw.records,
      decisions: [decision],
    );
    await mount(manual, memoryCount: 1);
    expect(find.text('この画面で本人確認・未保存 1件'), findsOneWidget);
    expect(find.text('この画面で同じ収入として本人確認・未保存'), findsOneWidget);
    expect(find.text('既存明細IDで照合'), findsNothing);
    await mount(linked(101));
    expect(find.textContaining('矛盾 1件'), findsOneWidget);
    expect(find.text('記録上の収入を照合済み'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '別件として照合'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        AssetIncomeReconciliationSection.issueLabel(
          IncomeEvidenceProblem.eventAmountConflict,
        ),
      ),
      findsOneWidget,
    );
  });
  testWidgets(
      'all four absent sources display uncalculated, never an invented zero',
      (tester) async {
    final empty = AssetIncomeSourceEvidence.project(
      ownerId: 'synthetic',
      currency: 'JPY',
      records: const [],
    );
    expect(empty.sourceRecordedTotals, isEmpty);
    expect(empty.combinedRecordedTotal, isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetIncomeReconciliationSection(
              projection: empty,
              busy: false,
              onReload: () {},
              onDecision: (left, right, relationship) {},
              onClear: () {},
              onPage: (page) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('収入の照合が必要'));
    await tester.pumpAndSettle();
    for (final label in ['収入フロー', '受取済み計画', '給与明細', '給与会計']) {
      expect(find.text('$label記録計: 未計算'), findsOneWidget);
    }
    expect(find.textContaining('JPY 0'), findsNothing);
  });
}
