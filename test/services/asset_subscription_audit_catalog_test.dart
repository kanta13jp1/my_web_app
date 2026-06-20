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
}
