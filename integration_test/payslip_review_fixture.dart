import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payslip_review_store.dart';
import 'package:my_web_app/widgets/asset_payslip_review_dialog.dart';

Map<String, dynamic> syntheticPayslip() => {
      'id': 'synthetic-statement',
      'user_id': 'synthetic-owner',
      'pay_date': '2030-01-20',
      'company_name': '合成給与',
      'gross_amount': 1000,
      'net_amount': 700,
      'taxable_amount': 900,
      'social_insurance_total': 200,
      'deductions': {
        'income_tax': 50,
        'resident_tax': 40,
        'health_insurance': 80,
        'pension': 100,
        'employment_insurance': 20,
        'long_term_care_insurance': 0,
        'employees_pension_fund_contribution': 0,
        'ideco': 10,
      },
      'earnings': {'base_salary': 1000},
      'attendance': {'work_days': 20},
      'source_pdf_path': 'payslips/synthetic-owner/statement.pdf',
      'parsed_by': 'synthetic',
      'confidence': 0.8,
      'raw_text_sha256': 'synthetic-hash',
      'review_status': 'auto',
      'created_at': '2030-01-20T00:00:00Z',
      'updated_at': '2030-01-20T00:00:00Z',
    };

class SyntheticPayslipReviewStore implements PayslipReviewStore {
  @override
  String get ownerId => 'synthetic-owner';
  bool active = true;
  @override
  bool get isCurrentOwner => active;
  final changes = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get ownerChanges => changes.stream;
  Map<String, dynamic> data = syntheticPayslip();
  int writes = 0;
  int originalRequests = 0;
  bool failAfterCommit = false;
  bool failReads = false;
  void changeOwner() {
    active = false;
    changes.add(null);
  }

  Future<void> dispose() => changes.close();
  @override
  Future<PayslipReviewSnapshot> load(String id) async {
    if (!active || failReads) throw StateError('Synthetic unavailable');
    return PayslipReviewSnapshot(data);
  }

  @override
  Future<void> confirm(
    PayslipReviewSnapshot expected, {
    required bool confirmedDisplayedValues,
  }) async {
    final current = await load(expected.id);
    if (!confirmedDisplayedValues ||
        !expected.sameVersion(current) ||
        expected.blockingReason != null) {
      throw StateError('Synthetic stale or unconfirmed');
    }
    writes++;
    data = {
      ...data,
      'review_status': 'confirmed',
      'updated_at': '2030-01-20T00:00:01Z',
    };
    if (failAfterCommit) throw StateError('Synthetic response lost');
  }

  @override
  Future<Uri> originalPdf(PayslipReviewSnapshot expected) async {
    if (!active) throw StateError('Synthetic owner mismatch');
    originalRequests++;
    return Uri.parse('https://example.invalid/synthetic.pdf');
  }
}

Future<void> showPayslipReview(
  WidgetTester tester,
  SyntheticPayslipReviewStore store, {
  double textScale = 1,
  Future<bool> Function(Uri)? openPdf,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: AssetPayslipReviewDialog(
          store: store,
          payslipId: 'synthetic-statement',
          openPdf: openPdf,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
