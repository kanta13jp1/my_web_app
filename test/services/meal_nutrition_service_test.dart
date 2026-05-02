import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/meal_nutrition_service.dart';

void main() {
  group('MealNutritionService', () {
    final service = MealNutritionService();

    test('estimates known chain meals from menu text', () {
      final yoshinoya = service.estimate('今日の昼は吉野家 うな重');
      expect(yoshinoya.profileId, 'yoshinoya_unaju');
      expect(yoshinoya.facts.calories, 750);
      expect(yoshinoya.facts.vegetablesG, lessThan(50));

      final sukiya = service.estimate('夜 すき家 うな牛');
      expect(sukiya.profileId, 'sukiya_unagyu');
      expect(sukiya.facts.calories, 870);
      expect(sukiya.facts.sodiumMg, greaterThan(2400));
    });

    test('falls back to a generic eating-out profile', () {
      final estimate = service.estimate('駅前の外食');
      expect(estimate.profileId, 'generic_meal');
      expect(estimate.confidence, lessThan(0.5));
      expect(estimate.facts.calories, 650);
    });

    test('summarizes weekly balance and warns for vegetables and sodium', () {
      final now = DateTime(2026, 5, 2, 12);
      final logs = List<MealNutritionLog>.generate(7, (index) {
        return MealNutritionLog(
          loggedAt: now.subtract(Duration(days: index)),
          estimate: service.estimate('すき家 うな牛'),
        );
      });

      final summary = service.summarize(logs, now: now);
      expect(summary.logs, hasLength(7));
      expect(summary.dailyAverage.calories, 870);
      expect(summary.warnings.join('\n'), contains('野菜不足'));
      expect(summary.warnings.join('\n'), contains('塩分過多'));
    });

    test('encodes and decodes logs for local persistence', () {
      final logs = <MealNutritionLog>[
        MealNutritionLog(
          loggedAt: DateTime(2026, 5, 2, 8),
          estimate: service.estimate('野菜サラダ'),
        ),
      ];

      final restored = service.decodeLogs(service.encodeLogs(logs));
      expect(restored, hasLength(1));
      expect(restored.single.estimate.profileId, 'vegetable_salad');
      expect(restored.single.loggedAt, DateTime(2026, 5, 2, 8));
    });
  });
}
