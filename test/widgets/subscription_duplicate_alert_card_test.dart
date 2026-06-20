import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_subscription_duplicate_detector.dart';
import 'package:my_web_app/widgets/subscription_duplicate_alert_card.dart';

void main() {
  const googleGroup = SubscriptionDuplicateGroup(
    providerKey: 'google',
    providerLabel: 'Google',
    members: <SubscriptionDuplicateMember>[
      (
        id: 'a',
        name: 'Google One 100GB',
        amount: 290,
        gateway: AssetSubscriptionBillingGateway.apple,
      ),
      (
        id: 'b',
        name: 'Google AI Pro 5TB',
        amount: 2900,
        gateway: AssetSubscriptionBillingGateway.direct,
      ),
    ],
  );

  testWidgets('renders nothing when there are no groups', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionDuplicateAlertCard(
            groups: const <SubscriptionDuplicateGroup>[],
            onIgnore: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(Card), findsNothing);
    expect(find.text('重複の可能性'), findsNothing);
  });

  testWidgets('renders groups with members + gateway and fires ignore',
      (tester) async {
    SubscriptionDuplicateGroup? ignored;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionDuplicateAlertCard(
            groups: const <SubscriptionDuplicateGroup>[googleGroup],
            onIgnore: (group) => ignored = group,
          ),
        ),
      ),
    );

    expect(find.text('重複の可能性'), findsOneWidget);
    expect(find.textContaining('Google（2件'), findsOneWidget);
    // メンバーは金額 + 経路 (Apple経由) を表示。
    expect(
      find.textContaining('Google One 100GB ¥290・Apple経由'),
      findsOneWidget,
    );
    expect(find.textContaining('Google AI Pro 5TB ¥2,900'), findsOneWidget);

    await tester.tap(find.text('重複ではない (非表示)'));
    expect(ignored?.providerKey, 'google');
  });
}
