import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/asset_must_task_deadline.dart';

void main() {
  test('deadline remains current through the end of its local day', () {
    for (final hour in [0, 9, 23]) {
      expect(
        isAssetMustTaskOverdue(
          deadline: DateTime(2026, 11, 13, 9, 15),
          now: DateTime(2026, 11, 13, hour, 59, 59),
          isCompleted: false,
        ),
        false,
      );
    }
  });

  test('overdue starts on the next day, including month and year boundaries',
      () {
    for (final deadline in [DateTime(2026, 11, 30), DateTime(2026, 12, 31)]) {
      final nextDay = DateTime(deadline.year, deadline.month, deadline.day + 1);
      expect(
        isAssetMustTaskOverdue(
          deadline: deadline,
          now: nextDay,
          isCompleted: false,
        ),
        true,
      );
      expect(
        isAssetMustTaskOverdue(
          deadline: nextDay,
          now: deadline,
          isCompleted: false,
        ),
        false,
      );
    }
  });

  test('completed tasks are never overdue', () {
    expect(
      isAssetMustTaskOverdue(
        deadline: DateTime(2026, 1, 1),
        now: DateTime(2026, 11, 13),
        isCompleted: true,
      ),
      false,
    );
  });

  test('picked midnight and unchanged initial date have the same semantics',
      () {
    final initial = assetMustTaskDate(DateTime(2026, 11, 13, 18, 45));
    expect(initial, DateTime(2026, 11, 13));
    for (final deadline in [initial, DateTime(2026, 11, 13)]) {
      expect(
        isAssetMustTaskOverdue(
          deadline: deadline,
          now: DateTime(2026, 11, 13, 23, 59),
          isCompleted: false,
        ),
        false,
      );
    }
  });

  test('UTC serialized deadlines use the same calendar date as their display',
      () {
    for (final utc in [
      DateTime.utc(2026, 11, 30, 23, 30),
      DateTime.utc(2026, 12, 31, 1, 30),
    ]) {
      final local = utc.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      expect(assetMustTaskDate(utc), day);
      expect(
        isAssetMustTaskOverdue(
          deadline: utc,
          now: DateTime(day.year, day.month, day.day, 23, 59),
          isCompleted: false,
        ),
        false,
      );
      expect(
        isAssetMustTaskOverdue(
          deadline: utc,
          now: DateTime(day.year, day.month, day.day + 1),
          isCompleted: false,
        ),
        true,
      );
    }
  });
}
