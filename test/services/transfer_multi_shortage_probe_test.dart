import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
void main() {
 test('combined proposals preserve the donor reserve across two shortages', () {
  final book = const AssetLiabilityPlanningService().buildWorkbook(
   latestSnapshot: <String,double>{'cash':100000,'bank':0,'other':0,'mobit':-100000,'PayPayカード':-100000},
   baseDate: DateTime(2026,5,1),
   monthlyPaymentOverrides: const <String,double>{'mobit':50000,'PayPayカード':50000},
   paymentSourceAccountIds: const <String,String>{'mobit':'custom_bank','PayPayカード':'custom_other'},
  );
  final shortages = book.accountCashflowSummaries.where((x)=>x.isShort).toList();
  expect(shortages,hasLength(2),reason:'fixture must contain two independent shortages');
  expect(book.transferSuggestions,isNotEmpty);
  final total = book.transferSuggestions.where((x)=>x.fromAccountId=='custom_cash').fold<double>(0,(a,x)=>a+x.amount);
  expect(total,lessThanOrEqualTo(70000),reason:'100000 current cash minus 30000 reserve must cover the combined plan');
 });
}
