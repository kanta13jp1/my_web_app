import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_subscription_audit_catalog.dart';

void main() {
  SubscriptionAuditAccountView account(
    String id,
    String name,
    AssetLiabilityAccountKind kind,
  ) =>
      (id: id, name: name, kind: kind);

  group('AssetSubscriptionAuditCatalog', () {
    test('manual sources cover Apple/au/Google with stable unique ids', () {
      final ids =
          AssetSubscriptionAuditCatalog.manualSources.map((s) => s.id).toList();
      expect(
        ids,
        containsAll(<String>['apple_id', 'au_kantan', 'google_play']),
      );
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    });

    test('every manual source is manualCheck with at least one step', () {
      for (final source in AssetSubscriptionAuditCatalog.manualSources) {
        expect(source.kind, SubscriptionAuditSourceKind.manualCheck);
        expect(source.name.trim(), isNotEmpty);
        expect(source.checkSteps, isNotEmpty);
        for (final step in source.checkSteps) {
          expect(step.trim(), isNotEmpty);
        }
      }
    });

    test('bank source is autoAssisted and has the contract id', () {
      expect(
        AssetSubscriptionAuditCatalog.bankSource.kind,
        SubscriptionAuditSourceKind.autoAssisted,
      );
      expect(
        AssetSubscriptionAuditCatalog.bankSource.id,
        AssetSubscriptionAuditCatalog.bankSourceId,
      );
    });

    test('cardSourceId composes a stable prefixed id', () {
      expect(
        AssetSubscriptionAuditCatalog.cardSourceId('aupay_card'),
        'card_aupay_card',
      );
    });
  });

  group('AssetSubscriptionAuditCatalog.bucketUnregisteredCounts', () {
    final accounts = <SubscriptionAuditAccountView>[
      account('aupay_card', 'auPayカード', AssetLiabilityAccountKind.creditCard),
      account('smbc', '三井住友銀行', AssetLiabilityAccountKind.deposit),
      account('wallet', '財布', AssetLiabilityAccountKind.cash),
      account('rent', '家賃', AssetLiabilityAccountKind.otherLiability),
    ];

    test('routes card/bank names and folds unknown+null to bank', () {
      final counts = AssetSubscriptionAuditCatalog.bucketUnregisteredCounts(
        accounts: accounts,
        suggestedSourceNames: <String?>[
          'auPayカード', // → card
          '三井住友銀行', // → bank (deposit)
          '財布', // → bank (cash)
          '謎サービス', // 未知 → bank
          null, // 不明 → bank
        ],
      );
      expect(counts['card_aupay_card'], 1);
      expect(counts[AssetSubscriptionAuditCatalog.bankSourceId], 4);
    });

    test('non card/cash/deposit account name falls back to bank', () {
      // 家賃 (otherLiability) は引落元マップに載らない → 銀行へフォールバック。
      final counts = AssetSubscriptionAuditCatalog.bucketUnregisteredCounts(
        accounts: accounts,
        suggestedSourceNames: const <String?>['家賃'],
      );
      expect(counts[AssetSubscriptionAuditCatalog.bankSourceId], 1);
      expect(counts.containsKey('card_rent'), isFalse);
    });

    test('same-named cards collapse onto the last scanned id (pinned)', () {
      // 検出器は口座名しか持たないため、同名カードは最後に走査した id へ寄る。
      final counts = AssetSubscriptionAuditCatalog.bucketUnregisteredCounts(
        accounts: <SubscriptionAuditAccountView>[
          account('card_a', '共通カード', AssetLiabilityAccountKind.creditCard),
          account('card_b', '共通カード', AssetLiabilityAccountKind.creditCard),
        ],
        suggestedSourceNames: const <String?>['共通カード', '共通カード'],
      );
      // 件数は失わず (合計2)、後勝ちの card_card_b に集約される。
      expect(counts['card_card_b'], 2);
      expect(counts.containsKey('card_card_a'), isFalse);
    });

    test('empty detections yield an empty map', () {
      expect(
        AssetSubscriptionAuditCatalog.bucketUnregisteredCounts(
          accounts: accounts,
          suggestedSourceNames: const <String?>[],
        ),
        isEmpty,
      );
    });
  });

  group('AssetSubscriptionAuditCatalog gateway mapping', () {
    test('sourceIdForGateway maps non-direct gateways to manual source ids',
        () {
      expect(
        AssetSubscriptionAuditCatalog.sourceIdForGateway(
          AssetSubscriptionBillingGateway.direct,
        ),
        isNull,
      );
      expect(
        AssetSubscriptionAuditCatalog.sourceIdForGateway(
          AssetSubscriptionBillingGateway.apple,
        ),
        AssetSubscriptionAuditCatalog.appleSourceId,
      );
      expect(
        AssetSubscriptionAuditCatalog.sourceIdForGateway(
          AssetSubscriptionBillingGateway.googlePlay,
        ),
        AssetSubscriptionAuditCatalog.googlePlaySourceId,
      );
      expect(
        AssetSubscriptionAuditCatalog.sourceIdForGateway(
          AssetSubscriptionBillingGateway.auKantan,
        ),
        AssetSubscriptionAuditCatalog.auKantanSourceId,
      );
    });

    test('gatewayForSourceId is the inverse and null for unknown/bank', () {
      expect(
        AssetSubscriptionAuditCatalog.gatewayForSourceId(
          AssetSubscriptionAuditCatalog.appleSourceId,
        ),
        AssetSubscriptionBillingGateway.apple,
      );
      expect(
        AssetSubscriptionAuditCatalog.gatewayForSourceId(
          AssetSubscriptionAuditCatalog.bankSourceId,
        ),
        isNull,
      );
      expect(
        AssetSubscriptionAuditCatalog.gatewayForSourceId('card_aupay'),
        isNull,
      );
    });

    test('manual source ids align with the gateway mapping constants', () {
      // カタログ定義の id と経路マッピングが drift しないことを pin。
      final manualIds =
          AssetSubscriptionAuditCatalog.manualSources.map((s) => s.id).toSet();
      expect(manualIds, contains(AssetSubscriptionAuditCatalog.appleSourceId));
      expect(
        manualIds,
        contains(AssetSubscriptionAuditCatalog.googlePlaySourceId),
      );
      expect(
        manualIds,
        contains(AssetSubscriptionAuditCatalog.auKantanSourceId),
      );
    });

    test('gatewayTotalsBySourceId sums by gateway, excludes direct & non-pos',
        () {
      final totals = AssetSubscriptionAuditCatalog.gatewayTotalsBySourceId(
        subscriptions: const <({
          AssetSubscriptionBillingGateway gateway,
          double amount,
        })>[
          (gateway: AssetSubscriptionBillingGateway.apple, amount: 30000),
          (gateway: AssetSubscriptionBillingGateway.apple, amount: 1500),
          (gateway: AssetSubscriptionBillingGateway.apple, amount: 980),
          (gateway: AssetSubscriptionBillingGateway.googlePlay, amount: 1200),
          (gateway: AssetSubscriptionBillingGateway.direct, amount: 3000),
          (gateway: AssetSubscriptionBillingGateway.apple, amount: 0),
        ],
      );
      final apple = totals[AssetSubscriptionAuditCatalog.appleSourceId];
      expect(apple?.count, 3);
      expect(apple?.total, 32480);
      expect(
        totals[AssetSubscriptionAuditCatalog.googlePlaySourceId]?.count,
        1,
      );
      // direct と 0円 は集計対象外。Apple と Google の 2 ソースのみ。
      expect(totals.length, 2);
    });
  });

  group('AssetSubscriptionAuditCatalog.gatewayCardBreakdownBySourceId', () {
    SubscriptionGatewayInput sub(
      AssetSubscriptionBillingGateway gateway,
      double amount,
      String? sourceAccountId,
    ) {
      return (
        gateway: gateway,
        amount: amount,
        sourceAccountId: sourceAccountId,
      );
    }

    test('splits an Apple gateway across funding cards, sorted by total', () {
      final subs = <SubscriptionGatewayInput>[
        sub(AssetSubscriptionBillingGateway.apple, 30000, 'famipay'),
        sub(AssetSubscriptionBillingGateway.apple, 1500, 'famipay'),
        sub(AssetSubscriptionBillingGateway.apple, 240, 'paypay'),
        sub(AssetSubscriptionBillingGateway.apple, 590, 'paypay'),
        sub(AssetSubscriptionBillingGateway.direct, 2900, 'paypay'),
      ];
      final breakdown =
          AssetSubscriptionAuditCatalog.gatewayCardBreakdownBySourceId(
        subscriptions: subs,
      );
      final apple = breakdown[AssetSubscriptionAuditCatalog.appleSourceId]!;
      // ファミペイ (31,500) → PayPay (830) の降順。
      final cardIds = apple.map((c) => c.fundingAccountId).toList();
      expect(cardIds, <String?>['famipay', 'paypay']);
      expect(apple[0].total, 31500);
      expect(apple[0].count, 2);
      expect(apple[1].total, 830);
      // direct は対象外なので Apple ソースのみ。
      expect(breakdown.length, 1);
    });

    test('unset funding card groups under null and sorts to the end', () {
      final subs = <SubscriptionGatewayInput>[
        sub(AssetSubscriptionBillingGateway.apple, 1000, null),
        sub(AssetSubscriptionBillingGateway.apple, 5000, 'famipay'),
        sub(AssetSubscriptionBillingGateway.apple, 200, ''),
      ];
      final breakdown =
          AssetSubscriptionAuditCatalog.gatewayCardBreakdownBySourceId(
        subscriptions: subs,
      );
      final apple = breakdown[AssetSubscriptionAuditCatalog.appleSourceId]!;
      expect(apple.map((c) => c.fundingAccountId), <String?>['famipay', null]);
      // null グループは 1000 + 200 (空文字も未設定扱い)。
      expect(apple.last.fundingAccountId, isNull);
      expect(apple.last.total, 1200);
    });

    test('normalizeFundingCard keeps known ids; unknown/empty/null → null', () {
      const known = <String>{'famipay', 'paypay'};
      final keep =
          AssetSubscriptionAuditCatalog.normalizeFundingCard('famipay', known);
      expect(keep, 'famipay');
      expect(
        AssetSubscriptionAuditCatalog.normalizeFundingCard('deleted', known),
        isNull,
      );
      expect(
        AssetSubscriptionAuditCatalog.normalizeFundingCard('', known),
        isNull,
      );
      expect(
        AssetSubscriptionAuditCatalog.normalizeFundingCard(null, known),
        isNull,
      );
    });

    test('unknown card ids merge into the unset group after normalize', () {
      const known = <String>{'famipay'};
      String? norm(String? id) {
        return AssetSubscriptionAuditCatalog.normalizeFundingCard(id, known);
      }

      final subs = <SubscriptionGatewayInput>[
        sub(AssetSubscriptionBillingGateway.apple, 1000, norm('deleted_card')),
        sub(AssetSubscriptionBillingGateway.apple, 200, norm(null)),
        sub(AssetSubscriptionBillingGateway.apple, 5000, norm('famipay')),
      ];
      final breakdown =
          AssetSubscriptionAuditCatalog.gatewayCardBreakdownBySourceId(
        subscriptions: subs,
      );
      final apple = breakdown[AssetSubscriptionAuditCatalog.appleSourceId]!;
      // famipay (5000) と 未設定 (1000+200) の 2 グループ。削除済みは未設定へ統合。
      expect(apple.length, 2);
      expect(apple.last.fundingAccountId, isNull);
      expect(apple.last.total, 1200);
    });
  });
}
