import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/thought_interrupt_quick_widget.dart';

void main() {
  testWidgets('ThoughtInterruptQuickWidget opens TOT support sheet',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ThoughtInterruptQuickWidget(),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('thought_interrupt_tot_support_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('thought_interrupt_tot_support_sheet')),
      findsOneWidget,
    );
    expect(find.text('言葉が出ない'), findsWidgets);
    expect(find.text('ストレスレベル 3 / 5'), findsOneWidget);
    expect(find.textContaining('言いたい単語を3つ'), findsOneWidget);

    await tester
        .tap(find.byKey(const Key('thought_interrupt_tot_state_stress')));
    await tester.pumpAndSettle();

    expect(find.textContaining('顎と肩の力を抜き'), findsOneWidget);

    final slider = tester.widget<Slider>(
      find.byKey(const Key('thought_interrupt_tot_stress_slider')),
    );
    slider.onChanged?.call(5);
    await tester.pumpAndSettle();

    expect(find.text('ストレスレベル 5 / 5'), findsOneWidget);
    expect(find.textContaining('まず60秒で止め'), findsOneWidget);
  });
}
