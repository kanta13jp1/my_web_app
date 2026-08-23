import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_recurring_fixed_cost_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetRecurringFixedCost model', () {
    test('appliesToMonth respects cadence', () {
      const monthly = AssetRecurringFixedCost(
        id: 'a',
        name: '電気代',
        amount: 8000,
        paymentDay: 27,
      );
      const evenMonth = AssetRecurringFixedCost(
        id: 'b',
        name: '町内会費',
        amount: 1000,
        paymentDay: 10,
        cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
      );
      const oddMonth = AssetRecurringFixedCost(
        id: 'c',
        name: '雑誌購読',
        amount: 1200,
        paymentDay: 5,
        cadence: AssetRecurringFixedCostCadence.bimonthlyOddMonth,
      );

      expect(monthly.appliesToMonth(6), isTrue);
      expect(monthly.appliesToMonth(7), isTrue);
      expect(evenMonth.appliesToMonth(6), isTrue);
      expect(evenMonth.appliesToMonth(7), isFalse);
      expect(oddMonth.appliesToMonth(6), isFalse);
      expect(oddMonth.appliesToMonth(7), isTrue);
    });

    test('fromJson rejects invalid values (lenient)', () {
      expect(AssetRecurringFixedCost.fromJson('', _validJson()), isNull);
      expect(
        AssetRecurringFixedCost.fromJson('x', {..._validJson(), 'name': ' '}),
        isNull,
      );
      expect(
        AssetRecurringFixedCost.fromJson('x', {..._validJson(), 'amount': 0}),
        isNull,
      );
      expect(
        AssetRecurringFixedCost.fromJson(
          'x',
          {..._validJson(), 'paymentDay': 32},
        ),
        isNull,
      );
      // 未知の cadence は monthly にフォールバック。
      final fallback = AssetRecurringFixedCost.fromJson(
        'x',
        {..._validJson(), 'cadence': 'weird'},
      );
      expect(fallback, isNotNull);
      expect(fallback!.cadence, AssetRecurringFixedCostCadence.monthly);
    });

    test('category defaults to utility and is omitted from json', () {
      const cost = AssetRecurringFixedCost(
        id: 'a',
        name: '電気代',
        amount: 8000,
        paymentDay: 27,
      );
      expect(cost.category, AssetRecurringFixedCostCategory.utility);
      // 既定 (utility) のときは既存ペイロードと互換のため category を出力しない。
      expect(cost.toJson().containsKey('category'), isFalse);
    });

    test('subscription category round-trips through json', () {
      const cost = AssetRecurringFixedCost(
        id: 'sub_claude',
        name: 'Anthropic (Claude)',
        amount: 3000,
        paymentDay: 1,
        category: AssetRecurringFixedCostCategory.subscription,
      );
      final json = cost.toJson();
      expect(json['category'], 'subscription');
      final restored = AssetRecurringFixedCost.fromJson('sub_claude', json);
      expect(restored, isNotNull);
      expect(
        restored!.category,
        AssetRecurringFixedCostCategory.subscription,
      );
    });

    test('subscription review decision round-trips through json', () {
      const cost = AssetRecurringFixedCost(
        id: 'sub_claude',
        name: 'Anthropic (Claude)',
        amount: 3000,
        paymentDay: 1,
        category: AssetRecurringFixedCostCategory.subscription,
        subscriptionReviewDecision:
            AssetSubscriptionReviewDecision.cancelCandidate,
      );
      final json = cost.toJson();
      expect(json['subscriptionReviewDecision'], 'cancelCandidate');
      final restored = AssetRecurringFixedCost.fromJson('sub_claude', json);
      expect(
        restored!.subscriptionReviewDecision,
        AssetSubscriptionReviewDecision.cancelCandidate,
      );
    });

    test('legacy subscription defaults review decision to unreviewed', () {
      final restored = AssetRecurringFixedCost.fromJson(
        'sub_legacy',
        {..._validJson(), 'category': 'subscription'},
      );
      expect(
        restored!.subscriptionReviewDecision,
        AssetSubscriptionReviewDecision.unreviewed,
      );
    });

    test('fromJson without category defaults to utility (back-compat)', () {
      // category キーが無い旧データ。
      final restored = AssetRecurringFixedCost.fromJson('x', _validJson());
      expect(restored, isNotNull);
      expect(restored!.category, AssetRecurringFixedCostCategory.utility);
    });

    test('fromJson with unknown category falls back to utility', () {
      final restored = AssetRecurringFixedCost.fromJson(
        'x',
        {..._validJson(), 'category': 'weird'},
      );
      expect(restored, isNotNull);
      expect(restored!.category, AssetRecurringFixedCostCategory.utility);
    });

    test('copyWith updates category', () {
      const cost = AssetRecurringFixedCost(
        id: 'a',
        name: 'Notion',
        amount: 1650,
        paymentDay: 5,
      );
      final updated = cost.copyWith(
        category: AssetRecurringFixedCostCategory.subscription,
      );
      expect(updated.category, AssetRecurringFixedCostCategory.subscription);
      // 他フィールドは保持。
      expect(updated.name, 'Notion');
      expect(updated.amount, 1650);
    });

    test('billingGateway defaults to direct and is omitted from json', () {
      const cost = AssetRecurringFixedCost(
        id: 'a',
        name: '電気代',
        amount: 8000,
        paymentDay: 27,
      );
      expect(cost.billingGateway, AssetSubscriptionBillingGateway.direct);
      expect(cost.toJson().containsKey('billingGateway'), isFalse);
    });

    test('apple gateway round-trips through json', () {
      const cost = AssetRecurringFixedCost(
        id: 'sub_chatgpt',
        name: 'ChatGPT Pro',
        amount: 30000,
        paymentDay: 20,
        category: AssetRecurringFixedCostCategory.subscription,
        billingGateway: AssetSubscriptionBillingGateway.apple,
      );
      final json = cost.toJson();
      expect(json['billingGateway'], 'apple');
      final restored = AssetRecurringFixedCost.fromJson('sub_chatgpt', json);
      expect(restored!.billingGateway, AssetSubscriptionBillingGateway.apple);
    });

    test('fromJson without/unknown gateway falls back to direct (back-compat)',
        () {
      final noKey = AssetRecurringFixedCost.fromJson('x', _validJson());
      expect(noKey!.billingGateway, AssetSubscriptionBillingGateway.direct);
      final weird = AssetRecurringFixedCost.fromJson(
        'x',
        {..._validJson(), 'billingGateway': 'weird'},
      );
      expect(weird!.billingGateway, AssetSubscriptionBillingGateway.direct);
    });

    test('copyWith updates billingGateway', () {
      const cost = AssetRecurringFixedCost(
        id: 'a',
        name: 'iCloud+',
        amount: 1500,
        paymentDay: 20,
        category: AssetRecurringFixedCostCategory.subscription,
      );
      final updated = cost.copyWith(
        billingGateway: AssetSubscriptionBillingGateway.apple,
      );
      expect(updated.billingGateway, AssetSubscriptionBillingGateway.apple);
      expect(updated.name, 'iCloud+');
    });
  });

  group('AssetRecurringFixedCostStore category', () {
    test('mirror value preserves subscription category', () {
      const costs = <AssetRecurringFixedCost>[
        AssetRecurringFixedCost(
          id: 'sub_openai',
          name: 'OpenAI (ChatGPT)',
          amount: 3000,
          paymentDay: 1,
          category: AssetRecurringFixedCostCategory.subscription,
        ),
      ];
      final encoded = AssetRecurringFixedCostStore.encodeMirrorValue(costs);
      final decoded = AssetRecurringFixedCostStore.decodeMirrorValue(encoded);
      expect(
        decoded.single.category,
        AssetRecurringFixedCostCategory.subscription,
      );
    });
  });

  group('AssetRecurringFixedCostStore', () {
    const store = AssetRecurringFixedCostStore();

    test('round-trips a list through SharedPreferences sorted by day',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'fc_denki',
            name: '電気代',
            amount: 8000,
            paymentDay: 27,
            sourceAccountId: 'smbc_otsuka_branch',
          ),
          AssetRecurringFixedCost(
            id: 'fc_nhk',
            name: 'NHK受信料',
            amount: 1300,
            paymentDay: 10,
            cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
          ),
        ],
        prefs: prefs,
      );

      final loaded = await store.load(prefs: prefs);
      // 振替日昇順 (10 → 27)。
      expect(loaded.map((c) => c.id), ['fc_nhk', 'fc_denki']);
      expect(loaded[1].name, '電気代');
      expect(loaded[1].amount, 8000);
      expect(loaded[1].sourceAccountId, 'smbc_otsuka_branch');
      expect(
        loaded[0].cadence,
        AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
      );
    });

    test('returns empty list when nothing stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      expect(await store.load(prefs: prefs), isEmpty);
    });

    test('save with empty list clears the key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'fc_denki',
            name: '電気代',
            amount: 8000,
            paymentDay: 27,
          ),
        ],
        prefs: prefs,
      );
      await store.save(const <AssetRecurringFixedCost>[], prefs: prefs);
      expect(await store.load(prefs: prefs), isEmpty);
    });

    test('encode/decode mirror value round-trips (端末A→端末B 同期)', () {
      const costs = <AssetRecurringFixedCost>[
        AssetRecurringFixedCost(
          id: 'fc_denki',
          name: '電気代',
          amount: 8000,
          paymentDay: 27,
        ),
      ];
      final encoded = AssetRecurringFixedCostStore.encodeMirrorValue(costs);
      final decoded = AssetRecurringFixedCostStore.decodeMirrorValue(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.id, 'fc_denki');
      expect(decoded.first.amount, 8000);
    });

    test('decodeMirrorValue drops malformed entries', () {
      expect(AssetRecurringFixedCostStore.decodeMirrorValue(null), isEmpty);
      expect(
        AssetRecurringFixedCostStore.decodeMirrorValue('not a map'),
        isEmpty,
      );
      final decoded = AssetRecurringFixedCostStore.decodeMirrorValue(
        <String, dynamic>{
          'fc_denki': <String, dynamic>{
            'name': '電気代',
            'amount': 8000,
            'paymentDay': 27,
          },
          'fc_bad': <String, dynamic>{
            'name': '',
            'amount': 0,
            'paymentDay': 99,
          },
          'fc_broken': 'oops',
        },
      );
      expect(decoded.map((c) => c.id), ['fc_denki']);
    });
  });
}

Map<String, dynamic> _validJson() {
  return <String, dynamic>{
    'name': '電気代',
    'amount': 8000,
    'paymentDay': 27,
    'cadence': 'monthly',
  };
}
