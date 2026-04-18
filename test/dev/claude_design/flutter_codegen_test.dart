import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/dev/claude_design/handoff_bundle.dart';
import 'package:my_web_app/dev/claude_design/flutter_codegen.dart';

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
  });
}
