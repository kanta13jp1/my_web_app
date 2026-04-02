import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/abstinence_guard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'AbstinenceGuardPage shows absolute quit panel for alcohol and smoking',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: () => DateTime(2026, 3, 21, 9),
          initialDate: DateTime(2026, 3, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    final panel = find.byKey(
      const Key('abstinence_guard_absolute_quit_panel'),
    );
    await tester.scrollUntilVisible(panel, 200, scrollable: scrollable);

    expect(panel, findsOneWidget);
    expect(
      find.byKey(const Key('abstinence_guard_absolute_quit_alcohol')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('abstinence_guard_absolute_quit_smoking')),
      findsOneWidget,
    );

    final enableAlcohol = find.byKey(
      const Key('abstinence_guard_absolute_enable_alcohol'),
    );
    await tester.tap(enableAlcohol);
    await tester.pumpAndSettle();

    final removeStockStep = find.byKey(
      const Key('abstinence_guard_absolute_step_alcohol_remove_stock'),
    );
    await tester.tap(removeStockStep);
    await tester.pumpAndSettle();

    final stepWidget = tester.widget<CheckboxListTile>(removeStockStep);
    expect(stepWidget.value, isTrue);
  });

  testWidgets('AbstinenceGuardPage records discipline training entries',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: () => DateTime(2026, 3, 21, 9),
          initialDate: DateTime(2026, 3, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('abstinence_guard_discipline_panel')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('abstinence_guard_discipline_record_no_buy')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(2),
      'コンビニに寄らなかった',
    );

    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    expect(find.text('我慢回数 1回'), findsOneWidget);
    expect(find.text('防いだ出費 1,500円'), findsOneWidget);
    expect(find.text('取り戻した時間 15分'), findsOneWidget);
    expect(find.text('コンビニに寄らなかった'), findsOneWidget);
  });
}
