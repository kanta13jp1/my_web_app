import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payslip_item_label.dart';
import '../../integration_test/payslip_review_fixture.dart';

void main() {
  testWidgets('original dialog labels known keys without changing source or saving', (tester) async {
    final store = SyntheticPayslipReviewStore();
    final earnings = <String, dynamic>{
      for (final key in PayslipItemLabel.earnings.keys) key: 0,
      'future_key': -1.5,
      'missing_key': null,
    };
    store.data['earnings'] = earnings;
    store.data['attendance'] = {'days_worked': 20, 'work_days': 0, 'overtime_hours': 1.5, 'future_hours': 2};
    await showPayslipReview(tester, store);
    for (final entry in PayslipItemLabel.earnings.entries) {
      expect(find.text('${entry.value}：0'), findsWidgets);
    }
    expect(find.text('出勤日数：20'), findsOneWidget);
    expect(find.text('勤務日数：0日'), findsOneWidget);
    expect(find.text('時間外時間：1.5時間'), findsOneWidget);
    expect(find.text('その他（future_hours）：2'), findsOneWidget);
    expect(find.text('その他（future_key）：-1.5'), findsOneWidget);
    expect(find.text('その他（missing_key）：未取得'), findsOneWidget);
    expect(store.data['earnings'], earnings);
    expect(store.writes, 0);
    expect(store.originalRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });
}
