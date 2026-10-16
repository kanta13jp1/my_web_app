import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_income_source_evidence.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/widgets/asset_income_reconciliation_section.dart';

IncomeEvidenceProjection sample() => AssetSalarySpendingEntries.projectCycle(
  ownerId: 'synthetic', flowOwnerId: 'synthetic', financeOwnerId: 'synthetic',
  reference: DateTime(2026, 6, 20), salaryDay: 25,
  recentFlows: const [{'id': 'f1', 'action_type': 'conquer', 'occurred_at': '2026-06-20', 'amount': 100}],
  payslipSalaryIncomes: const [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 100}],
  payslipRows: const [], monthlyIncomePlans: const [],
);

void main() {
  for (final same in [true, false]) {
    testWidgets('confirmation is required before memory decision same=$same', (tester) async {
      var decisions = 0;
      IncomeRelationship? result;
      var clears = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: AssetIncomeReconciliationSection(
          projection: sample(), busy: false, onReload: () {},
          onDecision: (left, right, relationship) { decisions++; result = relationship; },
          onClear: () { clears++; }, onPage: (_) {},
        ),
      ),),),);
      await tester.tap(find.text('収入の照合が必要')); await tester.pumpAndSettle();
      final button = find.text(same ? '同じ収入として照合' : '別件として照合');
      await tester.ensureVisible(button); await tester.tap(button); await tester.pumpAndSettle();
      expect(decisions, 0);
      expect(find.textContaining('この画面内の記録集計にだけ反映'), findsOneWidget);
      await tester.tap(find.text('戻る')); await tester.pumpAndSettle(); expect(decisions, 0);
      await tester.tap(button); await tester.pumpAndSettle();
      await tester.tap(find.text('この画面で照合する')); await tester.pumpAndSettle();
      expect(decisions, 1);
      expect(result, same ? IncomeRelationship.sameEvent : IncomeRelationship.distinctEvents);
      await tester.ensureVisible(find.text('この画面の照合を取り消す'));
      await tester.tap(find.text('この画面の照合を取り消す')); expect(clears, 1);
    });
  }
  testWidgets('failed or limited read explains withheld total, disables decisions, permits retry at narrow width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final problem in [IncomeEvidenceProblem.readUnconfirmed, IncomeEvidenceProblem.readLimitReached]) {
      var reloads = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: AssetIncomeReconciliationSection(
          key: ValueKey(problem), projection: withholdIncomeEvidence(sample(), reason: problem), busy: false,
          onReload: () { reloads++; }, onDecision: (_, _, _) => fail('unconfirmed read must not permit decisions'),
          onClear: () {}, onPage: (_) {},
        ),
      ),),),);
      await tester.tap(find.text('収入の照合が必要')); await tester.pumpAndSettle();
      expect(find.text(AssetIncomeReconciliationSection.issueLabel(problem)), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '同じ収入として照合')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '別件として照合')).onPressed, isNull);
      await tester.ensureVisible(find.text('既存明細を再読込'));
      await tester.tap(find.text('既存明細を再読込')); expect(reloads, 1);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('bounded relationship page exposes navigation without silently dropping pairs', (tester) async {
    final value = AssetSalarySpendingEntries.projectCycle(
      ownerId: 'synthetic', flowOwnerId: 'synthetic', financeOwnerId: 'synthetic',
      reference: DateTime(2026, 6, 20), salaryDay: 25,
      recentFlows: List.generate(8, (i) => {'id': 'f$i', 'action_type': 'conquer', 'occurred_at': '2026-06-20', 'amount': 100},),
      payslipSalaryIncomes: List.generate(8, (i) => {'id': 's$i', 'pay_date': '2026-06-20', 'amount': 100},),
      payslipRows: const [], monthlyIncomePlans: const [],
    );
    expect(value.unresolvedRelationshipCount, greaterThan(20));
    expect(value.issues.where((i) => i.problem == IncomeEvidenceProblem.missingRelationship), hasLength(20));
    int? page;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: AssetIncomeReconciliationSection(projection: value, busy: false,
        onReload: () {}, onDecision: (_, _, _) {}, onClear: () {}, onPage: (next) { page = next; },
      ),
    ),),),);
    await tester.tap(find.text('収入の照合が必要')); await tester.pumpAndSettle();
    final next = find.text('次の照合対象'); await tester.ensureVisible(next); await tester.tap(next);
    expect(page, 1);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '前の照合対象')).onPressed, isNull);
  });

}
