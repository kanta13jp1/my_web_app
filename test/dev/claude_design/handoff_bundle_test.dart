import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/dev/claude_design/handoff_bundle.dart';

void main() {
  group('ClaudeDesignHandoff', () {
    final sampleJson = {
      'tokens': {
        'colors': {'primary': '#6366F1', 'accent': '#FF6B35'},
        'typography': {
          'body': {'fontSize': 14.0, 'fontWeight': '400'},
        },
        'spacing': {'md': 16.0},
        'radius': {'lg': 12.0},
      },
      'components': [
        {'name': 'primary-button', 'htmlSnippet': '<button>Click me</button>'},
      ],
      'pages': [
        {'name': 'Home', 'route': '/', 'description': 'Landing page'},
      ],
      'sourceBundleId': 'bundle-abc-123',
      'importedAt': '2026-04-18T00:00:00.000Z',
    };

    test('fromJson round-trip', () {
      final bundle = ClaudeDesignHandoff.fromJson(sampleJson);
      expect(bundle.sourceBundleId, 'bundle-abc-123');
      expect(bundle.components.length, 1);
      expect(bundle.pages.length, 1);
      expect(bundle.tokens.colors.containsKey('primary'), isTrue);

      final json = bundle.toJson();
      final bundle2 = ClaudeDesignHandoff.fromJson(json);
      expect(bundle2.sourceBundleId, bundle.sourceBundleId);
      expect(bundle2.components.length, bundle.components.length);
    });

    test('color parsing from 6-digit hex', () {
      final bundle = ClaudeDesignHandoff.fromJson(sampleJson);
      final primary = bundle.tokens.colors['primary'];
      expect(primary, isNotNull);
      expect(primary!.toARGB32(), const Color(0xFF6366F1).toARGB32());
    });

    test('typography parsing', () {
      final bundle = ClaudeDesignHandoff.fromJson(sampleJson);
      final body = bundle.tokens.typography['body'];
      expect(body, isNotNull);
      expect(body!.fontSize, 14.0);
      expect(body.fontWeight, FontWeight.w400);
    });

    test('spacing and radius', () {
      final bundle = ClaudeDesignHandoff.fromJson(sampleJson);
      expect(bundle.tokens.spacing['md'], 16.0);
      expect(bundle.tokens.radius['lg'], 12.0);
    });

    test('empty JSON produces defaults', () {
      final bundle = ClaudeDesignHandoff.fromJson({});
      expect(bundle.components, isEmpty);
      expect(bundle.pages, isEmpty);
      expect(bundle.tokens.colors, isEmpty);
    });

    test('fromJson with missing optional fields', () {
      final bundle = ClaudeDesignHandoff.fromJson({
        'components': [],
        'pages': [],
        'tokens': {},
      });
      expect(bundle.sourceBundleId, isNull);
      expect(bundle.importedAt, isNotNull);
    });
  });

  group('DesignComponent', () {
    test('fromJson', () {
      final c = DesignComponent.fromJson({
        'name': 'card',
        'htmlSnippet': '<div>content</div>',
        'props': {'variant': 'elevated'},
      });
      expect(c.name, 'card');
      expect(c.htmlSnippet, '<div>content</div>');
      expect(c.props['variant'], 'elevated');
    });
  });
}
