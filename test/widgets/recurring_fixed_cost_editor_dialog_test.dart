import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_editor_dialog.dart';

void main() {
  group('recurringFixedCostSourceOptions', () {
    AssetLiabilityAccount acct(
      String id,
      String name,
      AssetLiabilityAccountKind kind,
      double balance,
    ) {
      return AssetLiabilityAccount(
        id: id,
        name: name,
        kind: kind,
        balance: balance,
      );
    }

    final accounts = <AssetLiabilityAccount>[
      acct('smbc', '三井住友銀行', AssetLiabilityAccountKind.deposit, 100000),
      acct('aupay', 'auPayカード', AssetLiabilityAccountKind.creditCard, 5000),
      acct('famipay', 'ファミペイカード', AssetLiabilityAccountKind.creditCard, 0),
      acct('mobit', 'モビット', AssetLiabilityAccountKind.cardLoan, -50000),
      acct(
        'acom_shopping',
        'アコムショッピング',
        AssetLiabilityAccountKind.shoppingDebt,
        -180000,
      ),
    ];

    test('default excludes non-positive cards (banks/positive cards only)', () {
      final ids =
          recurringFixedCostSourceOptions(accounts).map((o) => o.id).toList();
      // 残高>0 の銀行と auPay は出る。残高0のファミペイと負債は出ない。
      expect(ids, containsAll(<String>['smbc', 'aupay']));
      expect(ids, isNot(contains('famipay')));
      expect(ids, isNot(contains('mobit')));
      expect(ids, isNot(contains('acom_shopping')));
    });

    test('includeCards surfaces cards and shopping credit', () {
      final ids = recurringFixedCostSourceOptions(
        accounts,
        includeCards: true,
      ).map((o) => o.id).toList();
      // ファミペイ (creditCard / 残高0) とアコムショッピング枠 (shoppingDebt) が選べる。
      expect(
        ids,
        containsAll(<String>['smbc', 'aupay', 'famipay', 'acom_shopping']),
      );
      // 現金借入の消費者ローン (cardLoan) は買い物の請求先でないため含めない。
      expect(ids, isNot(contains('mobit')));
      // 重複しない (auPay は1回だけ)。
      expect(ids.where((id) => id == 'aupay').length, 1);
    });

    test('includeCarrierBilling surfaces au/KDDI carrier accounts only', () {
      final withCarrier = <AssetLiabilityAccount>[
        ...accounts,
        acct('au', 'au', AssetLiabilityAccountKind.otherLiability, -28797),
        acct('kddi_provider', 'KDDI', AssetLiabilityAccountKind.utility, -5764),
        acct('rent', '家賃', AssetLiabilityAccountKind.utility, -63000),
      ];
      final ids = recurringFixedCostSourceOptions(
        withCarrier,
        includeCards: true,
        includeCarrierBilling: true,
      ).map((o) => o.id).toList();
      // au / KDDI (auかんたん決済 / 通信料金合算) は振替元に出る。
      expect(ids, containsAll(<String>['au', 'kddi_provider']));
      // 家賃 (utility だがキャリア決済でない) は出ない。
      expect(ids, isNot(contains('rent')));
      // auPayカードを au と誤判定しない (残高>0 のカードとして1回だけ)。
      expect(ids.where((id) => id == 'aupay').length, 1);
    });

    test('carrier accounts stay hidden without includeCarrierBilling', () {
      final withCarrier = <AssetLiabilityAccount>[
        ...accounts,
        acct('au', 'au', AssetLiabilityAccountKind.otherLiability, -28797),
      ];
      final ids = recurringFixedCostSourceOptions(
        withCarrier,
        includeCards: true,
      ).map((o) => o.id).toList();
      expect(ids, isNot(contains('au')));
    });
  });

  const prefill = AssetRecurringFixedCost(
    id: 'fc_suggestion',
    name: '電気代',
    amount: 8050,
    paymentDay: 15,
  );

  testWidgets('prefill initializes the add form in add mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecurringFixedCostEditorDialog(prefill: prefill)),
      ),
    );

    expect(find.text('定期固定費を追加'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '電気代'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8050'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
  });

  testWidgets('saving a prefilled form returns a cost with a fresh id', (
    tester,
  ) async {
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await showRecurringFixedCostEditor(
                  context,
                  prefill: prefill,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, '電気代');
    expect(saved!.amount, 8050);
    expect(saved!.paymentDay, 15);
    expect(saved!.id, isNot('fc_suggestion')); // 新規 id を採番
  });

  testWidgets('subscription prefill shows subscription title', (tester) async {
    const subPrefill = AssetRecurringFixedCost(
      id: 'sub_preset_anthropic',
      name: 'Anthropic (Claude)',
      amount: 3000,
      paymentDay: 1,
      category: AssetRecurringFixedCostCategory.subscription,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecurringFixedCostEditorDialog(prefill: subPrefill),
        ),
      ),
    );

    expect(find.text('サブスクを追加'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Anthropic (Claude)'),
      findsOneWidget,
    );
  });

  testWidgets('category param defaults the add form to subscription', (
    tester,
  ) async {
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await showRecurringFixedCostEditor(
                  context,
                  category: AssetRecurringFixedCostCategory.subscription,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('サブスクを追加'), findsOneWidget);

    // 区分は DropdownButtonFormField のため TextFormField の並びは name/amount/day。
    await tester.enterText(find.byType(TextFormField).at(0), 'Supabase');
    await tester.enterText(find.byType(TextFormField).at(1), '3800');
    await tester.enterText(find.byType(TextFormField).at(2), '5');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Supabase');
    expect(saved!.category, AssetRecurringFixedCostCategory.subscription);
  });

  testWidgets('editing an existing subscription preserves its category', (
    tester,
  ) async {
    const existing = AssetRecurringFixedCost(
      id: 'sub_existing',
      name: 'Notion',
      amount: 1650,
      paymentDay: 5,
      category: AssetRecurringFixedCostCategory.subscription,
    );
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await showRecurringFixedCostEditor(
                  context,
                  existing: existing,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('サブスクを編集'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.id, 'sub_existing'); // 既存 id を保持
    expect(saved!.category, AssetRecurringFixedCostCategory.subscription);
  });

  testWidgets('区分ドロップダウンで utility→subscription に切り替えて保存できる', (
    tester,
  ) async {
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                // 既定 (utility) の追加モードで開く。
                saved = await showRecurringFixedCostEditor(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('定期固定費を追加'), findsOneWidget);

    // 区分ドロップダウンを開いて「サブスク」を選ぶ (onChanged→setState の配線を検証)。
    await tester.tap(
      find.byType(DropdownButtonFormField<AssetRecurringFixedCostCategory>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('サブスク').last);
    await tester.pumpAndSettle();
    // タイトルが追従して切り替わる。
    expect(find.text('サブスクを追加'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Cursor');
    await tester.enterText(find.byType(TextFormField).at(1), '3000');
    await tester.enterText(find.byType(TextFormField).at(2), '10');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Cursor');
    expect(saved!.category, AssetRecurringFixedCostCategory.subscription);
  });

  testWidgets('請求経路ドロップダウンはサブスク時に表示され apple を保存できる', (
    tester,
  ) async {
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await showRecurringFixedCostEditor(
                  context,
                  category: AssetRecurringFixedCostCategory.subscription,
                  gateway: AssetSubscriptionBillingGateway.apple,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 請求経路ドロップダウンが表示される (Apple 既定)。
    expect(find.text('請求経路'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'ChatGPT Pro');
    await tester.enterText(find.byType(TextFormField).at(1), '30000');
    await tester.enterText(find.byType(TextFormField).at(2), '20');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved!.billingGateway, AssetSubscriptionBillingGateway.apple);
  });

  testWidgets('請求経路ドロップダウンは固定費(utility)では非表示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecurringFixedCostEditorDialog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('請求経路'), findsNothing);
  });

  testWidgets('サブスク→固定費へ区分変更すると請求経路は direct に戻して保存される', (
    tester,
  ) async {
    const existing = AssetRecurringFixedCost(
      id: 'sub_x',
      name: 'X Premium',
      amount: 980,
      paymentDay: 20,
      category: AssetRecurringFixedCostCategory.subscription,
      billingGateway: AssetSubscriptionBillingGateway.apple,
    );
    AssetRecurringFixedCost? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await showRecurringFixedCostEditor(
                  context,
                  existing: existing,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 区分を「定期固定費」へ切り替える。
    await tester.tap(
      find.byType(DropdownButtonFormField<AssetRecurringFixedCostCategory>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('定期固定費').last);
    await tester.pumpAndSettle();
    // 区分=utility になり請求経路ドロップダウンは消える。
    expect(find.text('請求経路'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.category, AssetRecurringFixedCostCategory.utility);
    expect(saved!.billingGateway, AssetSubscriptionBillingGateway.direct);
  });
}
