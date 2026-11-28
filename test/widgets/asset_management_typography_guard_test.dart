import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_spending_attention_calendar.dart';
import 'package:my_web_app/widgets/asset_attention_day_label.dart';
import 'package:my_web_app/widgets/asset_unreconciled_expense_badge.dart';

void _assertTypographyCompliance(String path) {
  final lines = File(path).readAsStringSync().split('\n');
  final fontSizePattern = RegExp(r'fontSize\s*:\s*([0-9]+(?:\.[0-9]+)?)');
  final lowHeightPattern =
      RegExp(r'\bheight\s*:\s*(1\.[0-3][0-9]*|0\.[0-9]+)\b');
  const styleMarkers = <String>[
    'TextStyle',
    'fontSize',
    'fontWeight',
    'letterSpacing',
    'copyWith',
  ];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final match in fontSizePattern.allMatches(line)) {
      final size = double.parse(match.group(1)!);
      expect(
        size,
        greaterThanOrEqualTo(10),
        reason: '$path:${i + 1} has fontSize < 10 ($size)',
      );
    }
    if (lowHeightPattern.hasMatch(line)) {
      final start = i - 2 < 0 ? 0 : i - 2;
      final end = i + 3 > lines.length ? lines.length : i + 3;
      final contextLines = lines.sublist(start, end).join(' ');
      final inTextStyle = styleMarkers.any(contextLines.contains);
      expect(
        inTextStyle,
        isFalse,
        reason: '$path:${i + 1} has TextStyle height < 1.4 ($line)',
      );
    }
  }
}

void main() {
  test('asset management UI files comply with DESIGN.md typography rules', () {
    const targets = <String>[
      'lib/pages/asset_management_page.dart',
      'lib/widgets/asset_unreconciled_expense_badge.dart',
      'lib/widgets/asset_attention_day_label.dart',
    ];
    for (final path in targets) {
      _assertTypographyCompliance(path);
    }
  });

  for (final scale in <double>[1, 2]) {
    testWidgets(
      'calendar badges enforce >=10px font and >=1.4 line-height at scale $scale',
      (WidgetTester tester) async {
        final day = AssetSpendingAttentionCalendar.forDate(
          DateTime(2026, 10, 16),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const AssetUnreconciledExpenseBadge(),
                        AssetAttentionDayLabel(day: day),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final unknownText = tester.widget<Text>(find.text('不明'));
        final attentionText = tester.widget<Text>(find.text('注意'));
        expect(unknownText.style?.fontSize, greaterThanOrEqualTo(10));
        expect(unknownText.style?.height, greaterThanOrEqualTo(1.4));
        expect(attentionText.style?.fontSize, greaterThanOrEqualTo(10));
        expect(attentionText.style?.height, greaterThanOrEqualTo(1.4));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
