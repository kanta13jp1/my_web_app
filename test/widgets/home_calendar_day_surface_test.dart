import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_day_surface.dart';

void main() {
  testWidgets('day border states', (tester) async {
    final muted = const Color(0xFFB0B0B0).withValues(alpha: 0.08);
    final cases = [
      (true, true, true, const Color(0xFF6366F1), 1.6),
      (true, true, false, const Color(0xFF6366F1), 1.6),
      (true, false, true, const Color(0xFF6366F1), 1.6),
      (true, false, false, const Color(0xFF6366F1), 1.6),
      (false, true, true, Colors.green.withValues(alpha: 0.22), 1.0),
      (false, true, false, muted, 1.0),
      (false, false, true, Colors.transparent, 1.0),
      (false, false, false, Colors.transparent, 1.0),
    ];
    for (final item in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 42,
              height: 86,
              child: HomeCalendarDaySurface(
                accentColor: const Color(0xFF4CAF50),
                isToday: item.$1,
                isCurrentMonth: item.$2,
                matchesFilter: item.$3,
                hasSlip: false,
                isClean: false,
                isUnset: false,
                child: const Text('7'),
              ),
            ),
          ),
        ),
      );
      final surface = find.byType(HomeCalendarDaySurface);
      final box = tester.widget<Container>(
        find.descendant(of: surface, matching: find.byType(Container)),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      final border = decoration.border! as Border;
      expect(border.top.color, item.$4);
      expect(border.top.width, item.$5);
      expect(border, Border.all(color: item.$4, width: item.$5));
      expect(tester.getSize(surface), const Size(42, 86));
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('day background states', (tester) async {
    final dim = const Color(0xFFB0B0B0).withValues(alpha: 0.035);
    final outside = const Color(0xFFB0B0B0).withValues(alpha: 0.05);
    final cases = [
      (true, true, true, false, false, Colors.green.withValues(alpha: 0.18)),
      (true, true, false, true, false, Colors.green.withValues(alpha: 0.14)),
      (true, true, false, false, true, Colors.green.withValues(alpha: 0.08)),
      (true, true, false, false, false, Colors.green.withValues(alpha: 0.1)),
      (true, false, true, true, true, dim),
      (false, true, true, true, true, outside),
    ];
    for (final item in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeCalendarDaySurface(
            accentColor: Colors.green,
            isToday: false,
            isCurrentMonth: item.$1,
            matchesFilter: item.$2,
            hasSlip: item.$3,
            isClean: item.$4,
            isUnset: item.$5,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(HomeCalendarDaySurface),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as BoxDecoration).color, item.$6);
    }
  });
}
