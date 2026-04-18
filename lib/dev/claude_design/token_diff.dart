import 'package:flutter/material.dart';
import 'handoff_bundle.dart';

enum ChangeKind { added, removed, modified, unchanged }

class TokenChange {
  final String key;
  final String tokenType;
  final ChangeKind kind;
  final String? oldValue;
  final String? newValue;

  const TokenChange({
    required this.key,
    required this.tokenType,
    required this.kind,
    this.oldValue,
    this.newValue,
  });

  @override
  String toString() => '[$tokenType] $key: $kind'
      '${oldValue != null ? " ($oldValue → $newValue)" : ""}';
}

class TokenDiff {
  final List<TokenChange> changes;

  const TokenDiff(this.changes);

  int get addedCount => changes.where((c) => c.kind == ChangeKind.added).length;
  int get removedCount =>
      changes.where((c) => c.kind == ChangeKind.removed).length;
  int get modifiedCount =>
      changes.where((c) => c.kind == ChangeKind.modified).length;
  int get unchangedCount =>
      changes.where((c) => c.kind == ChangeKind.unchanged).length;

  bool get hasChanges => addedCount + removedCount + modifiedCount > 0;

  List<TokenChange> get onlyChanges =>
      changes.where((c) => c.kind != ChangeKind.unchanged).toList();
}

TokenDiff diffTokens(DesignTokens current, DesignTokens incoming) {
  final changes = <TokenChange>[];

  changes.addAll(_diffColorMap(current.colors, incoming.colors));
  changes.addAll(_diffDoubleMap('spacing', current.spacing, incoming.spacing));
  changes.addAll(_diffDoubleMap('radius', current.radius, incoming.radius));

  return TokenDiff(changes);
}

List<TokenChange> _diffColorMap(
  Map<String, Color> current,
  Map<String, Color> incoming,
) {
  final changes = <TokenChange>[];
  final allKeys = {...current.keys, ...incoming.keys};

  for (final key in allKeys) {
    final cur = current[key];
    final inc = incoming[key];

    if (cur == null && inc != null) {
      changes.add(
        TokenChange(
          key: key,
          tokenType: 'color',
          kind: ChangeKind.added,
          newValue: _colorHex(inc),
        ),
      );
    } else if (cur != null && inc == null) {
      changes.add(
        TokenChange(
          key: key,
          tokenType: 'color',
          kind: ChangeKind.removed,
          oldValue: _colorHex(cur),
        ),
      );
    } else if (cur != null && inc != null && cur.toARGB32() != inc.toARGB32()) {
      changes.add(
        TokenChange(
          key: key,
          tokenType: 'color',
          kind: ChangeKind.modified,
          oldValue: _colorHex(cur),
          newValue: _colorHex(inc),
        ),
      );
    } else {
      changes.add(
        TokenChange(
          key: key,
          tokenType: 'color',
          kind: ChangeKind.unchanged,
        ),
      );
    }
  }

  return changes;
}

List<TokenChange> _diffDoubleMap(
  String tokenType,
  Map<String, double> current,
  Map<String, double> incoming,
) {
  final changes = <TokenChange>[];
  final allKeys = {...current.keys, ...incoming.keys};

  for (final key in allKeys) {
    final cur = current[key];
    final inc = incoming[key];

    if (cur == null && inc != null) {
      changes.add(
        TokenChange(
          key: key,
          tokenType: tokenType,
          kind: ChangeKind.added,
          newValue: inc.toString(),
        ),
      );
    } else if (cur != null && inc == null) {
      changes.add(
        TokenChange(
          key: key,
          tokenType: tokenType,
          kind: ChangeKind.removed,
          oldValue: cur.toString(),
        ),
      );
    } else if (cur != null && inc != null && cur != inc) {
      changes.add(
        TokenChange(
          key: key,
          tokenType: tokenType,
          kind: ChangeKind.modified,
          oldValue: cur.toString(),
          newValue: inc.toString(),
        ),
      );
    } else {
      changes.add(
        TokenChange(
          key: key,
          tokenType: tokenType,
          kind: ChangeKind.unchanged,
        ),
      );
    }
  }

  return changes;
}

String _colorHex(Color c) {
  final v = c.toARGB32();
  return '#${v.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

// Current DESIGN.md tokens for reference comparison
DesignTokens get currentDesignTokens => const DesignTokens(
      colors: {
        'primary': Color(0xFF6366F1),
        'accent': Color(0xFFFF6B35),
        'success': Color(0xFF0D9488),
        'error': Color(0xFFB91C1C),
        'surface0': Color(0xFF0A0A0A),
        'surface1': Color(0xFF1A1A2E),
        'surface2': Color(0xFF16213E),
        'text': Color(0xFFE2E8F0),
        'textMuted': Color(0xFF94A3B8),
        'border': Color(0xFF334155),
      },
      typography: {},
      spacing: {
        'xs': 4,
        'sm': 8,
        'md': 16,
        'lg': 24,
        'xl': 32,
        'xxl': 48,
      },
      radius: {
        'sm': 4,
        'md': 8,
        'lg': 12,
        'xl': 16,
        'pill': 24,
      },
    );
