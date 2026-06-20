import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_category_budget_store.dart';

void main() {
  group('AssetCategoryBudgetStore encode/decode', () {
    test('round-trips a budget map', () {
      final budgets = <String, double>{'食費': 50000, '住居': 63000};
      final encoded = AssetCategoryBudgetStore.encodeMirrorValue(budgets);
      final decoded = AssetCategoryBudgetStore.decodeMirrorValue(encoded);

      expect(decoded, budgets);
    });

    test('drops non-positive entries on encode', () {
      final encoded = AssetCategoryBudgetStore.encodeMirrorValue(
        <String, double>{'食費': 50000, '交通': 0, '医療': -100},
      );

      expect(encoded.keys, <String>['食費']);
    });

    test('drops invalid and non-positive entries on decode', () {
      final decoded = AssetCategoryBudgetStore.decodeMirrorValue(
        <String, dynamic>{'住居': 63000, '無効': 'x', '負': -5},
      );

      expect(decoded, <String, double>{'住居': 63000});
    });

    test('decode tolerates non-map input', () {
      expect(AssetCategoryBudgetStore.decodeMirrorValue(null), isEmpty);
      expect(AssetCategoryBudgetStore.decodeMirrorValue('oops'), isEmpty);
    });
  });
}
