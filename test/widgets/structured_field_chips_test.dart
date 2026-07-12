import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/structured_field_chips.dart';

void main() {
  group('structured field labels', () {
    test('priorityLabel maps values and defaults', () {
      expect(priorityLabel('p0'), 'P0 最優先');
      expect(priorityLabel('p3'), 'P3 低');
      expect(priorityLabel(null), '未設定');
      expect(priorityLabel('bogus'), '未設定');
    });

    test('effortLabel maps t-shirt sizes', () {
      expect(effortLabel('xs'), 'XS');
      expect(effortLabel('xl'), 'XL');
      expect(effortLabel(null), '—');
    });

    test('value domains match the DB CHECK constraints', () {
      expect(kPriorityValues, <String>['p0', 'p1', 'p2', 'p3']);
      expect(kEffortValues, <String>['xs', 's', 'm', 'l', 'xl']);
    });
  });

  group('formatTargetDate', () {
    test('normalizes date and timestamp strings to yyyy-MM-dd', () {
      // date カラムは常に yyyy-MM-dd、timestamptz は末尾を落として日付部を返す。
      expect(formatTargetDate('2026-07-12'), '2026-07-12');
      expect(formatTargetDate('2026-07-12T03:00:00Z'), '2026-07-12');
    });

    test('returns null for empty / null input', () {
      expect(formatTargetDate(''), isNull);
      expect(formatTargetDate(null), isNull);
    });
  });

  group('chips', () {
    test('return null when no value, a widget when present', () {
      expect(priorityChip(null), isNull);
      expect(priorityChip(''), isNull);
      expect(priorityChip('p0'), isA<Widget>());
      expect(effortChip('m'), isA<Widget>());
      expect(effortChip(null), isNull);
      expect(dueDateChip('2026-07-12'), isA<Widget>());
      expect(dueDateChip(null), isNull);
    });
  });
}
