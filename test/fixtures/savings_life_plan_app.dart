import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/widgets/savings_life_plan_card.dart';
import 'package:my_web_app/services/savings_plan_proposal_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const MaterialApp(home: SavingsFixture()));
}

class SavingsFixture extends StatelessWidget {
  const SavingsFixture({super.key});
  int get income =>
      int.tryParse(Uri.base.queryParameters['income'] ?? '') ?? 400000;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SavingsLifePlanCard(
              userId: 'synthetic-fixture',
              today: DateTime(2026, 10, 13),
              monthlyCommitments: 200000,
              commitmentsEstimated: true,
              suggestedIncome: income,
              proposalRevision: 'synthetic-fixture-v2',
              propose: () => SavingsPlanProposalService(
                allowExternalAi: () async => true,
                generate: (_) async {
                  if (Uri.base.queryParameters['ai'] == 'error')
                    throw StateError('synthetic offline');
                  return '{"living_costs":70000,"reserve":10000,"rationale":"架空家計・模擬AI応答です。食費と通勤費を確保し、日々の支出を確認します。"}';
                },
              ).propose(
                SavingsPlanProposalInput(
                  cashBalance: 400000,
                  monthlyIncome: income,
                  monthlyCommitments: 200000,
                  observedLivingExpense: 12000,
                  recordedDays: 5,
                  estimatedPayments: true,
                ),
              ),
              onReviewPayments: () {},
            ),
          ),
        ),
      );
}
