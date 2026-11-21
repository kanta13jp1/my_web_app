import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('buildMyProjectInputDecoration', () {
    test('sets explicit dark fill and high-contrast hint color', () {
      final decoration = buildMyProjectInputDecoration('プロジェクト名');

      expect(decoration.hintText, 'プロジェクト名');
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, const Color(0xFF121212));
      expect(decoration.hintStyle?.color, const Color(0xFF9CA3AF));
    });

    testWidgets('keeps dark fill in light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          home: Scaffold(
            body: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: buildMyProjectInputDecoration('プロジェクト名'),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.filled, isTrue);
      expect(textField.decoration?.fillColor, const Color(0xFF121212));
      expect(find.text('プロジェクト名'), findsOneWidget);
    });
  });
}
