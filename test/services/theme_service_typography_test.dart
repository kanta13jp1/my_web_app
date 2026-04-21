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
  });
}
