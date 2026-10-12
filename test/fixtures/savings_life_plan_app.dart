import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/widgets/savings_life_plan_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const MaterialApp(home: SavingsFixture()));
}

class SavingsFixture extends StatelessWidget {
  const SavingsFixture({super.key});
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
            suggestedIncome: 400000,
            onReviewPayments: () {},
          ),
        ),),
      );
}
