import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/dev/claude_design/flutter_codegen.dart';
import 'package:my_web_app/dev/claude_design/handoff_bundle.dart';
import 'package:my_web_app/theme/claude_design_generated_theme.dart';

void main() {
  group('FlutterCodegen', () {
    test('button → ElevatedButton', () {
      const c = DesignComponent(
        name: 'primary-button',
        htmlSnippet: '<button>Submit</button>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('ElevatedButton'));
      expect(code, contains('Submit'));
    });

    test('outlined button → OutlinedButton', () {
      const c = DesignComponent(
        name: 'outlined-btn',
        htmlSnippet: '<button style="border: 1px solid">Cancel</button>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('OutlinedButton'));
    });

    test('input → TextField', () {
      const c = DesignComponent(
        name: 'search-input',
        htmlSnippet: '<input placeholder="Search..." />',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('TextField'));
      expect(code, contains('Search...'));
    });

    test('img → Image.network', () {
      const c = DesignComponent(
        name: 'avatar',
        htmlSnippet: '<img src="https://example.com/img.png" alt="Avatar" />',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('Image.network'));
      expect(code, contains('https://example.com/img.png'));
    });

    test('img without src → Icon', () {
      const c = DesignComponent(
        name: 'placeholder-img',
        htmlSnippet: '<img alt="placeholder" />',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('Icon'));
    });

    test('h1 → Text with large style', () {
      const c = DesignComponent(
        name: 'page-title',
        htmlSnippet: '<h1>Hello World</h1>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('Text'));
      expect(code, contains('Hello World'));
      expect(code, contains('fontSize: 28'));
    });

    test('h2 → Text with medium style', () {
      const c = DesignComponent(
        name: 'section-title',
        htmlSnippet: '<h2>Section</h2>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('fontSize: 22'));
    });

    test('p → Text', () {
      const c = DesignComponent(
        name: 'paragraph',
        htmlSnippet: '<p>Body text here</p>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains("Text('Body text here')"));
    });

    test('div → Column by default', () {
      const c = DesignComponent(
        name: 'card',
        htmlSnippet:
            '<div style="display: flex; flex-direction: column"></div>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('Column'));
    });

    test('div row → Row', () {
      const c = DesignComponent(
        name: 'toolbar',
        htmlSnippet: '<div style="display: flex; flex-direction: row"></div>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('Row'));
    });

    test('empty html → SizedBox.shrink', () {
      const c = DesignComponent(name: 'empty', htmlSnippet: '');
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('SizedBox.shrink'));
    });

    test('generated code contains class name in PascalCase', () {
      const c = DesignComponent(
        name: 'my-button',
        htmlSnippet: '<button>Go</button>',
      );
      final code = FlutterCodegen.generateFromComponent(c);
      expect(code, contains('class MyButton'));
    });

    test('generateFromComponents handles empty list', () {
      final code = FlutterCodegen.generateFromComponents([]);
      expect(code, contains('No components'));
    });

    test('reportAsJson is valid JSON with count field', () {
      final components = [
        const DesignComponent(name: 'btn', htmlSnippet: '<button>OK</button>'),
      ];
      final json = FlutterCodegen.reportAsJson(components);
      expect(json, contains('"count": 1'));
    });

    test('generateThemeDataCode emits deterministic Material 3 ThemeData', () {
      const sampleBundle = DesignTokens(
        colors: <String, Color>{
          'primary': Color(0xFFFF6B35),
          'secondary': Color(0xFF3D5AFE),
          'surface0': Color(0xFF0A0A0A),
          'surface1': Color(0xFF1A1A1A),
          'text': Color(0xFFFFFFFF),
          'border': Color(0xFF2A2A2A),
        },
        typography: <String, TextStyle>{
          'bodyMedium': TextStyle(fontSize: 15, height: 1.5),
        },
        spacing: <String, double>{'md': 16},
        radius: <String, double>{'lg': 14},
      );
      final darkCode = FlutterCodegen.generateThemeDataCode(
        sampleBundle,
        className: 'BrandTheme',
      );
      expect(darkCode, contains('class BrandTheme'));
      expect(darkCode, contains('Color(0xFFFF6B35)'));
      expect(darkCode, contains('CardThemeData('));
      expect(darkCode, contains('DialogThemeData('));
      expect(darkCode, contains('Brightness.dark'));

      final lightCode = FlutterCodegen.generateThemeDataCode(
        sampleBundle,
        className: 'BrandTheme',
        brightness: Brightness.light,
      );
      expect(lightCode, contains('Brightness.light'));
    });

    test('ClaudeDesignGeneratedTheme builds valid light and dark ThemeData',
        () {
      final darkTheme = ClaudeDesignGeneratedTheme.buildThemeData();
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.brightness, Brightness.dark);
      expect(
        darkTheme.colorScheme.primary.toARGB32(),
        ClaudeDesignGeneratedTheme.primaryColor.toARGB32(),
      );
      final darkExt = darkTheme.extension<ClaudeDesignGeneratedThemeTokens>();
      expect(darkExt, isNotNull);
      expect(darkExt!.radiusLg, 16);

      final lightTheme = ClaudeDesignGeneratedTheme.buildThemeData(
        brightness: Brightness.light,
      );
      expect(lightTheme.brightness, Brightness.light);
      final lightExt = lightTheme.extension<ClaudeDesignGeneratedThemeTokens>();
      expect(lightExt, isNotNull);
      final copied = lightExt!.copyWith(spaceMd: 20);
      expect(copied.spaceMd, 20);
      final lerped = darkExt.lerp(lightExt, 0.5);
      expect(lerped.radiusLg, 16);
    });
  });
}
