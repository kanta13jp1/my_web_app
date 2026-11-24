import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService Japanese typography', () {
    test('light theme keeps readable Japanese body line heights', () {
      final theme = ThemeService().getLightTheme();

      expect(theme.textTheme.bodyLarge?.height, greaterThanOrEqualTo(1.7));
      expect(theme.textTheme.bodyMedium?.height, greaterThanOrEqualTo(1.7));
      expect(theme.textTheme.bodySmall?.height, greaterThanOrEqualTo(1.6));
      expect(theme.textTheme.labelLarge?.height, greaterThanOrEqualTo(1.5));
      expect(theme.textTheme.labelMedium?.height, greaterThanOrEqualTo(1.5));
      expect(theme.textTheme.labelSmall?.height, greaterThanOrEqualTo(1.5));
    });

    test('dark theme keeps the same Japanese body rhythm', () {
      final theme = ThemeService().getDarkTheme();

      expect(theme.textTheme.bodyLarge?.height, greaterThanOrEqualTo(1.7));
      expect(theme.textTheme.bodyMedium?.height, greaterThanOrEqualTo(1.7));
      expect(theme.textTheme.bodySmall?.height, greaterThanOrEqualTo(1.6));
      expect(theme.textTheme.labelLarge?.height, greaterThanOrEqualTo(1.5));
      expect(theme.textTheme.labelMedium?.height, greaterThanOrEqualTo(1.5));
      expect(theme.textTheme.labelSmall?.height, greaterThanOrEqualTo(1.5));
    });

    test('app font family is applied to both light and dark themes', () {
      final service = ThemeService();
      final lightBody = service.getLightTheme().textTheme.bodyMedium;
      final darkBody = service.getDarkTheme().textTheme.bodyMedium;

      expect(lightBody?.fontFamily, 'NotoSansJP');
      expect(darkBody?.fontFamily, 'NotoSansJP');
      expect(
        lightBody?.fontFamilyFallback,
        containsAll(<String>['NotoSansJP', 'NotoSans', 'NotoColorEmoji']),
      );
      expect(
        darkBody?.fontFamilyFallback,
        containsAll(<String>['NotoSansJP', 'NotoSans', 'NotoColorEmoji']),
      );
    });

    testWidgets(
      'AppBar foregroundColor overrides theme title color in light and dark themes',
      (WidgetTester tester) async {
        final service = ThemeService();
        for (final theme in <ThemeData>[
          service.getLightTheme(),
          service.getDarkTheme(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                appBar: AppBar(
                  backgroundColor: const Color(0xFF102B43),
                  foregroundColor: Colors.white,
                  title: const Text('経営コックピット'),
                ),
              ),
            ),
          );

          final context = tester.element(find.text('経営コックピット'));
          expect(DefaultTextStyle.of(context).style.color, Colors.white);

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey<Brightness>(theme.brightness),
              theme: theme,
              home: Scaffold(
                appBar: AppBar(title: const Text('通常タイトル')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final defaultContext = tester.element(find.text('通常タイトル'));
          expect(
            DefaultTextStyle.of(defaultContext).style.color,
            theme.appBarTheme.foregroundColor,
          );
        }
      },
    );
  });
}
