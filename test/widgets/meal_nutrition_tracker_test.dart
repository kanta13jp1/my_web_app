import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/meal_nutrition_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('logs a meal and shows weekly nutrition alerts', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MealNutritionTracker())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('meal_nutrition_input')),
      '吉野家 うな重',
    );
    await tester.tap(find.byKey(const Key('meal_nutrition_add_button')));
    await tester.pumpAndSettle();

    expect(find.text('吉野家 うな重'), findsWidgets);
    expect(find.textContaining('750 kcal'), findsWidgets);
    expect(find.byKey(const Key('meal_nutrition_week_chart')), findsOneWidget);
    expect(find.byKey(const Key('meal_nutrition_alerts')), findsOneWidget);
    expect(find.textContaining('野菜不足'), findsOneWidget);
  });
}
