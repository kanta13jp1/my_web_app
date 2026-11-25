import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final alt = ThemeService.catalog.where((d) => d.code != 'dark_ai').first;
  final altCode = alt.code;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ThemeService mode override persistence', () {
    test('setThemeMode clears overrideTheme and persists dark_ai', () async {
      expect(altCode, isNot('dark_ai'));
      final service = ThemeService();
      await _pumpMicrotasks();

      await service.applyThemeByCode(altCode);
      expect(service.selectedThemeCode, altCode);
      expect(service.overrideTheme, isNotNull);

      var notified = 0;
      service.addListener(() => notified++);

      service.setThemeMode(ThemeMode.dark);

      expect(service.overrideTheme, isNull);
      expect(service.selectedThemeCode, 'dark_ai');
      expect(service.themeMode, ThemeMode.dark);
      expect(notified, 1);

      await _pumpMicrotasks();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'ThemeMode.dark');
      expect(prefs.getString('catalog_theme_code'), 'dark_ai');
    });

    test('toggleTheme clears overrideTheme and switches mode', () async {
      final service = ThemeService();
      await _pumpMicrotasks();

      service.setThemeMode(ThemeMode.light);
      await _pumpMicrotasks();

      await service.applyThemeByCode(altCode);
      expect(service.themeMode, ThemeMode.light);
      expect(service.overrideTheme, isNotNull);

      service.toggleTheme();

      expect(service.overrideTheme, isNull);
      expect(service.selectedThemeCode, 'dark_ai');
      expect(service.themeMode, ThemeMode.dark);

      await _pumpMicrotasks();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'ThemeMode.dark');
      expect(prefs.getString('catalog_theme_code'), 'dark_ai');

      await service.applyThemeByCode(altCode);
      expect(service.overrideTheme, isNotNull);

      service.toggleTheme();

      expect(service.overrideTheme, isNull);
      expect(service.selectedThemeCode, 'dark_ai');
      expect(service.themeMode, ThemeMode.light);

      await _pumpMicrotasks();
      expect(prefs.getString('theme_mode'), 'ThemeMode.light');
      expect(prefs.getString('catalog_theme_code'), 'dark_ai');
    });

    test('fresh ThemeService preserves cleared catalog override', () async {
      final first = ThemeService();
      await _pumpMicrotasks();

      await first.applyThemeByCode(altCode);
      expect(first.overrideTheme, isNotNull);

      first.setThemeMode(ThemeMode.dark);
      await _pumpMicrotasks();

      final reloaded = ThemeService();
      var reloadedNotified = false;
      reloaded.addListener(() => reloadedNotified = true);
      await _pumpMicrotasks();

      expect(reloadedNotified, isTrue);
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.selectedThemeCode, 'dark_ai');
      expect(reloaded.overrideTheme, isNull);
    });
  });
}
