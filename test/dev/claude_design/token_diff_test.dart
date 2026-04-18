import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/dev/claude_design/handoff_bundle.dart';
import 'package:my_web_app/dev/claude_design/token_diff.dart';

DesignTokens _makeTokens({
  Map<String, Color> colors = const {},
  Map<String, double> spacing = const {},
  Map<String, double> radius = const {},
}) {
  return DesignTokens(
    colors: colors,
    typography: const {},
    spacing: spacing,
    radius: radius,
  );
}

void main() {
  group('diffTokens', () {
    test('identical tokens → all unchanged', () {
      final tokens = _makeTokens(
        colors: {'primary': const Color(0xFF6366F1)},
        spacing: {'md': 16},
      );
      final diff = diffTokens(tokens, tokens);
      expect(diff.hasChanges, isFalse);
      expect(diff.unchangedCount, greaterThan(0));
    });

    test('added color', () {
      final cur = _makeTokens();
      final inc = _makeTokens(colors: {'newColor': const Color(0xFF0D9488)});
      final diff = diffTokens(cur, inc);
      expect(diff.addedCount, 1);
      expect(diff.onlyChanges.first.key, 'newColor');
      expect(diff.onlyChanges.first.kind, ChangeKind.added);
    });

    test('removed color', () {
      final cur = _makeTokens(colors: {'oldColor': const Color(0xFFB91C1C)});
      final inc = _makeTokens();
      final diff = diffTokens(cur, inc);
      expect(diff.removedCount, 1);
      expect(diff.onlyChanges.first.kind, ChangeKind.removed);
    });

    test('modified color', () {
      final cur = _makeTokens(colors: {'primary': const Color(0xFF6366F1)});
      final inc = _makeTokens(colors: {'primary': const Color(0xFFFF6B35)});
      final diff = diffTokens(cur, inc);
      expect(diff.modifiedCount, 1);
      final change = diff.onlyChanges.first;
      expect(change.kind, ChangeKind.modified);
      expect(change.oldValue, contains('6366F1'));
      expect(change.newValue, contains('FF6B35'));
    });

    test('modified spacing', () {
      final cur = _makeTokens(spacing: {'md': 16});
      final inc = _makeTokens(spacing: {'md': 20});
      final diff = diffTokens(cur, inc);
      expect(diff.modifiedCount, 1);
    });

    test('added radius', () {
      final cur = _makeTokens();
      final inc = _makeTokens(radius: {'xl': 24});
      final diff = diffTokens(cur, inc);
      expect(diff.addedCount, 1);
    });

    test('TokenDiff counts sum correctly', () {
      final cur = _makeTokens(
        colors: {'a': const Color(0xFF6366F1), 'b': const Color(0xFF0D9488)},
      );
      final inc = _makeTokens(
        colors: {'a': const Color(0xFFFF6B35), 'c': const Color(0xFFB91C1C)},
      );
      final diff = diffTokens(cur, inc);
      expect(diff.addedCount, 1); // c added
      expect(diff.removedCount, 1); // b removed
      expect(diff.modifiedCount, 1); // a modified
    });
  });
}
