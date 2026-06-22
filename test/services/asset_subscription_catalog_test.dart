import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_subscription_catalog.dart';

void main() {
  group('AssetSubscriptionCatalog', () {
    test('presets are non-empty with unique ids and positive amounts', () {
      const presets = AssetSubscriptionCatalog.presets;
      expect(presets, isNotEmpty);
      final ids = presets.map((p) => p.id).toSet();
      expect(ids.length, presets.length, reason: 'preset ids must be unique');
      for (final preset in presets) {
        expect(preset.id.trim(), isNotEmpty);
        expect(preset.name.trim(), isNotEmpty);
        expect(preset.defaultMonthlyAmount, greaterThan(0));
      }
    });

    test('covers the headline AI/cloud providers', () {
      final ids = AssetSubscriptionCatalog.presets.map((p) => p.id).toSet();
      for (final required in const <String>[
        'anthropic',
        'openai',
        'gemini',
        'gcp',
        'supabase',
        'notion',
      ]) {
        expect(ids, contains(required), reason: 'missing preset: $required');
      }
    });

    test('toPrefill produces a subscription-category recurring fixed cost', () {
      final preset = AssetSubscriptionCatalog.presets
          .firstWhere((p) => p.id == 'anthropic');
      final draft = preset.toPrefill(paymentDay: 12);
      expect(draft.category, AssetRecurringFixedCostCategory.subscription);
      expect(draft.name, preset.name);
      expect(draft.amount, preset.defaultMonthlyAmount);
      expect(draft.paymentDay, 12);
      expect(draft.cadence, AssetRecurringFixedCostCadence.monthly);
    });

    test('toPrefill default payment day falls back to catalog default', () {
      final draft = AssetSubscriptionCatalog.presets.first.toPrefill();
      expect(draft.paymentDay, AssetSubscriptionCatalog.defaultPaymentDay);
      // 1〜31 の正当な振替日 (fromJson が受け付ける範囲)。
      expect(draft.paymentDay, inInclusiveRange(1, 31));
    });
  });
}
