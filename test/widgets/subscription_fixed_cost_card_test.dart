import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_subscription_catalog.dart';
import 'package:my_web_app/widgets/subscription_fixed_cost_card.dart';

void main() {
  const presets = <AssetSubscriptionPreset>[
    AssetSubscriptionPreset(
      id: 'anthropic',
      name: 'Anthropic (Claude)',
      defaultMonthlyAmount: 3000,
      note: 'Claude Pro 目安',
    ),
    AssetSubscriptionPreset(
      id: 'notion',
      name: 'Notion',
      defaultMonthlyAmount: 1650,
    ),
  ];

  group('SubscriptionFixedCostCard', () {
    testWidgets('renders preset chips and fires onAddPreset', (tester) async {
      AssetSubscriptionPreset? addedPreset;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionFixedCostCard(
              costs: const <AssetRecurringFixedCost>[],
              sourceAccountNames: const <String, String>{},
              presets: presets,
              onAddPreset: (preset) => addedPreset = preset,
              onAddCustom: () {},
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('サブスク (AI/クラウド)'), findsOneWidget);
      expect(find.textContaining('まだ登録がありません'), findsOneWidget);
      // 2 件のテンプレート chip。
      expect(
        find.widgetWithText(ActionChip, 'Anthropic (Claude)'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ActionChip, 'Notion'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Notion'));
      expect(addedPreset?.id, 'notion');
    });

    testWidgets('hides presets already registered (dedup by name)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionFixedCostCard(
              costs: const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_notion',
                  name: 'Notion',
                  amount: 1650,
                  paymentDay: 5,
                  category: AssetRecurringFixedCostCategory.subscription,
                ),
              ],
              sourceAccountNames: const <String, String>{},
              presets: presets,
              onAddPreset: (_) {},
              onAddCustom: () {},
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      // 登録済み Notion はリストに出るが、テンプレート chip からは消える。
      expect(find.text('Notion'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Notion'), findsNothing);
      expect(
        find.widgetWithText(ActionChip, 'Anthropic (Claude)'),
        findsOneWidget,
      );
    });

    testWidgets('renders registered entries and fires edit/delete/custom-add',
        (tester) async {
      AssetRecurringFixedCost? edited;
      AssetRecurringFixedCost? deleted;
      var customPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionFixedCostCard(
              costs: const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_claude',
                  name: 'Anthropic (Claude)',
                  amount: 3000,
                  paymentDay: 1,
                  category: AssetRecurringFixedCostCategory.subscription,
                  sourceAccountId: 'smbc',
                ),
              ],
              sourceAccountNames: const <String, String>{
                'smbc': '三井住友銀行',
              },
              presets: presets,
              onAddPreset: (_) {},
              onAddCustom: () => customPressed = true,
              onEdit: (cost) => edited = cost,
              onDelete: (cost) => deleted = cost,
            ),
          ),
        ),
      );

      expect(find.text('Anthropic (Claude)'), findsWidgets);
      expect(find.textContaining('毎月1日'), findsOneWidget);
      expect(find.textContaining('¥3,000'), findsOneWidget);
      expect(find.textContaining('振替元: 三井住友銀行'), findsOneWidget);

      // 行ごとに 名称+内訳 を 1 つの semantics ラベルへまとめる。
      final rowSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.contains('Anthropic (Claude)') ??
                false) &&
            (widget.properties.label?.contains('¥3,000') ?? false),
      );
      expect(rowSemantics, findsOneWidget);

      await tester.tap(find.text('その他を追加'));
      expect(customPressed, isTrue);
      await tester.tap(find.byTooltip('Anthropic (Claude) を編集'));
      expect(edited?.id, 'sub_claude');
      await tester.tap(find.byTooltip('Anthropic (Claude) を削除'));
      expect(deleted?.id, 'sub_claude');
    });

    testWidgets('shows the billing gateway suffix for Apple-billed subs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionFixedCostCard(
              costs: const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_chatgpt',
                  name: 'ChatGPT Pro',
                  amount: 30000,
                  paymentDay: 20,
                  category: AssetRecurringFixedCostCategory.subscription,
                  billingGateway: AssetSubscriptionBillingGateway.apple,
                ),
              ],
              sourceAccountNames: const <String, String>{},
              presets: presets,
              onAddPreset: (_) {},
              onAddCustom: () {},
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Apple経由'), findsOneWidget);
    });
  });
}
