import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/global_optin_promotion_service.dart';

void main() {
  group('GlobalOptInPromotionService', () {
    test('isolates tenant evaluations and blocks promotion under 3 tenants',
        () async {
      final store = InMemoryTenantEvaluationStore();
      var tick = DateTime.utc(2026, 11, 26, 1, 0, 0);
      final service = GlobalOptInPromotionService(
        store: store,
        nowProvider: () {
          tick = tick.add(const Duration(seconds: 1));
          return tick;
        },
      );

      // Two tenants rate item-a highly, plus duplicate update from tenant-1.
      await service.recordTenantEvaluation(
        tenantId: 'tenant-1',
        itemId: 'item-a',
        score: 0.95,
        usageScore: 0.80,
      );
      await service.recordTenantEvaluation(
        tenantId: 'tenant-1',
        itemId: 'item-a',
        score: 0.98,
        usageScore: 0.90,
      );
      await service.recordTenantEvaluation(
        tenantId: 'tenant-2',
        itemId: 'item-a',
        score: 0.85,
      );

      final sweep = await service.runPromotionAndDemotionSweep();
      expect(sweep.activeGlobalCount, 0);
      expect(sweep.promotedCount, 0);

      // Tenant-3 must see zero local/global leakage from tenant-1 or tenant-2.
      final rankedForTenant3 = await service.rankItemsForTenant(
        tenantId: 'tenant-3',
        candidateItemIds: const <String>['item-a'],
      );
      expect(rankedForTenant3, hasLength(1));
      expect(rankedForTenant3.first.isGlobalPromoted, isFalse);
      expect(rankedForTenant3.first.localScore, 0.0);
      expect(rankedForTenant3.first.globalScore, 0.0);
      expect(rankedForTenant3.first.compositeScore, 0.0);
    });

    test('promotes globally when >= 3 distinct tenants score >= 0.7', () async {
      final store = InMemoryTenantEvaluationStore();
      final service = GlobalOptInPromotionService(
        store: store,
        nowProvider: () => DateTime.utc(2026, 11, 26, 2, 0, 0),
      );

      await service.recordTenantEvaluation(
        tenantId: 'tenant-1',
        itemId: 'item-a',
        score: 0.70,
        usageScore: 0.50,
      );
      await service.recordTenantEvaluation(
        tenantId: 'tenant-2',
        itemId: 'item-a',
        score: 0.80,
      );
      await service.recordTenantEvaluation(
        tenantId: 'tenant-3',
        itemId: 'item-a',
        score: 0.90,
      );
      // Tenant-4 scores below 0.7 -> does not count toward qualifying mean.
      await service.recordTenantEvaluation(
        tenantId: 'tenant-4',
        itemId: 'item-a',
        score: 0.40,
      );

      final sweep = await service.runPromotionAndDemotionSweep();
      expect(sweep.promotedCount, 1);
      expect(sweep.activeGlobalCount, 1);
      expect(sweep.demotedCount, 0);

      final globalRecord = await store.getGlobalRecord('item-a');
      expect(globalRecord, isNotNull);
      expect(globalRecord!.isGlobalPromoted, isTrue);
      expect(globalRecord.qualifyingTenantCount, 3);
      expect(globalRecord.globalScore, closeTo(0.80, 1e-9));

      // Ranking for tenant-1: 0.70*0.70 + 0.20*0.80 + 0.10*0.50 = 0.49 + 0.16 + 0.05 = 0.70
      final ranked = await service.rankItemsForTenant(
        tenantId: 'tenant-1',
        candidateItemIds: const <String>['item-a'],
      );
      expect(ranked.first.isGlobalPromoted, isTrue);
      expect(ranked.first.compositeScore, closeTo(0.70, 1e-9));
    });

    test(
        'demotion_sweep demotes item when qualifying tenants fall below threshold',
        () async {
      final store = InMemoryTenantEvaluationStore();
      var tick = DateTime.utc(2026, 11, 26, 3, 0, 0);
      final service = GlobalOptInPromotionService(
        store: store,
        nowProvider: () {
          tick = tick.add(const Duration(seconds: 1));
          return tick;
        },
      );

      for (final tenant in const <String>['t1', 't2', 't3']) {
        await service.recordTenantEvaluation(
          tenantId: tenant,
          itemId: 'item-demote',
          score: 0.85,
        );
      }

      final firstSweep = await service.runPromotionAndDemotionSweep();
      expect(firstSweep.promotedCount, 1);
      expect(firstSweep.activeGlobalCount, 1);

      // t3 updates score below 0.7 -> only 2 tenants qualify now.
      await service.recordTenantEvaluation(
        tenantId: 't3',
        itemId: 'item-demote',
        score: 0.50,
      );

      final secondSweep = await service.runPromotionAndDemotionSweep();
      expect(secondSweep.demotedCount, 1);
      expect(secondSweep.activeGlobalCount, 0);

      final record = await store.getGlobalRecord('item-demote');
      expect(record, isNotNull);
      expect(record!.status, GlobalPromotionStatus.demoted);
      expect(record.isGlobalPromoted, isFalse);
      expect(record.globalScore, 0.0);
    });

    test('supports configurable threshold and minQualifyingTenants', () async {
      final store = InMemoryTenantEvaluationStore();
      final service = GlobalOptInPromotionService(
        store: store,
        config: const GlobalOptInConfig(
          minQualifyingTenants: 2,
          promotionThreshold: 0.85,
        ),
      );

      await service.recordTenantEvaluation(
        tenantId: 't1',
        itemId: 'item-cfg',
        score: 0.80,
      );
      await service.recordTenantEvaluation(
        tenantId: 't2',
        itemId: 'item-cfg',
        score: 0.90,
      );

      final blocked = await service.evaluateItemPromotion('item-cfg');
      expect(blocked.isGlobalPromoted, isFalse);

      await service.recordTenantEvaluation(
        tenantId: 't1',
        itemId: 'item-cfg',
        score: 0.88,
      );
      final promoted = await service.evaluateItemPromotion('item-cfg');
      expect(promoted.isGlobalPromoted, isTrue);
      expect(promoted.qualifyingTenantCount, 2);
    });
  });
}
