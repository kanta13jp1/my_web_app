import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/personal_dashboard_page.dart';

void main() {
  group('personalDashboardGridSpec', () {
    test('uses 4 columns on wide desktop', () {
      final spec = personalDashboardGridSpec(1280);

      expect(spec.crossAxisCount, 4);
      expect(spec.childAspectRatio, 1.38);
    });

    test('uses 2 columns on medium width', () {
      final spec = personalDashboardGridSpec(900);

      expect(spec.crossAxisCount, 2);
      expect(spec.childAspectRatio, 1.28);
    });

    test('uses 1 column on narrow width', () {
      final spec = personalDashboardGridSpec(420);

      expect(spec.crossAxisCount, 1);
      expect(spec.childAspectRatio, 2.2);
    });
  });

  group('personalDashboardBarHeightFactor', () {
    test('keeps a minimum visible height for zero values', () {
      final factor = personalDashboardBarHeightFactor(value: 0, maxValue: 0);

      expect(factor, 0.02);
    });

    test('scales non-zero values against the max', () {
      final factor = personalDashboardBarHeightFactor(value: 3, maxValue: 6);

      expect(factor, 0.5);
    });
  });

  group('personalDashboardHasRecordedData', () {
    test('returns false for zero-only fallback data', () {
      final hasData = personalDashboardHasRecordedData(
        kpiData: const {
          'total_notes': 0,
          'tasks_completed': 0,
          'focus_minutes': 0,
          'habit_streak': 0,
          'note_growth': 0,
          'task_rate': 0.0,
        },
        weeklyActivity: const [
          {'date': '04/21', 'notes': 0, 'tasks': 0, 'focus_min': 0},
        ],
        habitStats: const [],
        recentNotes: const [],
      );

      expect(hasData, isFalse);
    });

    test('returns true when recent notes exist', () {
      final hasData = personalDashboardHasRecordedData(
        kpiData: const {
          'total_notes': 0,
          'tasks_completed': 0,
          'focus_minutes': 0,
          'habit_streak': 0,
          'note_growth': 0,
          'task_rate': 0.0,
        },
        weeklyActivity: const [
          {'date': '04/21', 'notes': 0, 'tasks': 0, 'focus_min': 0},
        ],
        habitStats: const [],
        recentNotes: const [
          {'title': 'First note', 'updated_at': '2026-04-23T00:00:00Z'},
        ],
      );

      expect(hasData, isTrue);
    });
  });
}
