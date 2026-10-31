import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_deductions.dart';
import '../../integration_test/payslip_review_fixture.dart';

Finder saveButton() => find.widgetWithText(FilledButton, '記載内容を本人確認済みにする');
void cleanUp(WidgetTester tester, SyntheticPayslipReviewStore store) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });
}

Future<void> acknowledgeAndSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.ensureVisible(saveButton());
  await tester.tap(saveButton());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only explicit original comparison updates confirmation once',
      (tester) async {
    final store = SyntheticPayslipReviewStore();
    cleanUp(tester, store);
    var pdfOpened = 0;
    await showPayslipReview(
      tester,
      store,
      openPdf: (_) async {
        pdfOpened++;
        return true;
      },
    );
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    expect(store.originalRequests, 0);
    await tester.ensureVisible(find.text('保存済みの元PDFを開く'));
    await tester.tap(find.text('保存済みの元PDFを開く'));
    await tester.pumpAndSettle();
    expect(pdfOpened, 1);
    expect(store.writes, 0);
    await acknowledgeAndSave(tester);
    expect(store.writes, 1);
    expect(store.data['net_amount'], 700);
    expect(find.text('記載済み値は本人確認済み'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
  });
  testWidgets('unknown save reconciles without resend or attributing success',
      (tester) async {
    final store = SyntheticPayslipReviewStore()..failAfterCommit = true;
    cleanUp(tester, store);
    await showPayslipReview(tester, store);
    await acknowledgeAndSave(tester);
    expect(store.writes, 1);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    store.failReads = true;
    await tester.ensureVisible(find.text('確認保存の現在状態を照合'));
    await tester.tap(find.text('確認保存の現在状態を照合'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    store.failReads = false;
    await tester.tap(find.text('確認保存の現在状態を照合'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今回の操作で保存されたかは確定できません'), findsOneWidget);
    expect(store.writes, 1);
    await tester.pumpWidget(const SizedBox());
    await showPayslipReview(tester, store);
    expect(find.text('記載済み値は本人確認済み'), findsOneWidget);
    expect(store.writes, 1);
  });
  testWidgets('changed original cannot receive the previous confirmation',
      (tester) async {
    final store = SyntheticPayslipReviewStore();
    cleanUp(tester, store);
    await showPayslipReview(tester, store);
    store.data = {
      ...store.data,
      'net_amount': 701,
      'updated_at': '2030-01-20T00:00:02Z',
    };
    await acknowledgeAndSave(tester);
    expect(store.writes, 0);
    await tester.ensureVisible(find.text('確認保存の現在状態を照合'));
    await tester.tap(find.text('確認保存の現在状態を照合'));
    await tester.pumpAndSettle();
    expect(find.textContaining('元の記載内容が変わりました'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    expect(store.data['review_status'], 'auto');
  });
  testWidgets('owner switch clears the previous original and disables saving',
      (tester) async {
    final store = SyntheticPayslipReviewStore();
    cleanUp(tester, store);
    await showPayslipReview(tester, store);
    expect(find.textContaining('合成給与'), findsOneWidget);
    store.changeOwner();
    await tester.pumpAndSettle();
    expect(find.textContaining('合成給与'), findsNothing);
    expect(find.text('利用者が切り替わりました。明細を開き直してください。'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    expect(store.writes, 0);
  });
  testWidgets('missing fields stay unknown after explicit confirmation',
      (tester) async {
    final store = SyntheticPayslipReviewStore();
    cleanUp(tester, store);
    store.data = {
      ...store.data,
      'social_insurance_total': null,
      'deductions': {'income_tax': 50, 'resident_tax': 40},
    };
    await showPayslipReview(tester, store);
    await acknowledgeAndSave(tester);
    final month = AssetPayrollDeductions.months(
      ownerId: store.ownerId,
      year: 2030,
      rows: [store.data],
    ).first;
    expect(month.confirmedTaxYen, 90);
    expect(month.confirmedSocialYen, isNull);
    expect(month.summaryStatus(social: true), contains('必要項目の記載なし'));
    expect(
      (store.data['deductions'] as Map).containsKey('health_insurance'),
      isFalse,
    );
  });
  testWidgets('alias conflict blocks the explicit confirmation action',
      (tester) async {
    final store = SyntheticPayslipReviewStore();
    cleanUp(tester, store);
    (store.data['deductions'] as Map)['employees_pension_insurance'] = 99;
    await showPayslipReview(tester, store);
    expect(find.textContaining('項目名違いが競合'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    expect(store.writes, 0);
  });
}
