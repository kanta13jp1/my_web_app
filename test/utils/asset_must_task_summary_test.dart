import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/asset_must_task_summary.dart';

void main() {
  final month = DateTime(2026, 11, 13);
  final cached = <Map<String, dynamic>>[
    {
      'title': 'Synthetic cached task',
      'deadline': DateTime(2026, 11, 20).toIso8601String(),
      'is_completed': false,
    },
  ];

  test('failed empty and cached reads are unavailable, not unregistered', () {
    for (final tasks in [<Map<String, dynamic>>[], cached]) {
      final result = formatAssetMustTaskSummary(
        tasks: tasks,
        month: month,
        isLoading: false,
        loadFailed: true,
      );
      expect(result, contains('未取得（読込失敗。最新の登録状況は未確認）'));
      expect(result, isNot(contains('（未登録）')));
      expect(result, isNot(contains('Synthetic cached task')));
    }
  });

  test('loading does not expose a cached list as current', () {
    final result = formatAssetMustTaskSummary(
      tasks: cached,
      month: month,
      isLoading: true,
      loadFailed: false,
    );
    expect(result, contains('未取得（読込中）'));
    expect(result, isNot(contains('Synthetic cached task')));
  });

  test('successful empty read alone reports unregistered', () {
    final result = formatAssetMustTaskSummary(
      tasks: [],
      month: month,
      isLoading: false,
      loadFailed: false,
    );
    expect(result, contains('（未登録）'));
    expect(result, isNot(contains('未取得')));
  });

  test('recovery restores this month ordered tasks and completion marks', () {
    final tasks = [
      ...cached,
      {
        'title': 'Synthetic completed task',
        'deadline': DateTime(2026, 11, 10).toIso8601String(),
        'is_completed': true,
      },
      {
        'title': 'Synthetic other month',
        'deadline': DateTime(2026, 12, 1).toIso8601String(),
        'is_completed': false,
      },
    ];
    final result = formatAssetMustTaskSummary(
      tasks: tasks,
      month: month,
      isLoading: false,
      loadFailed: false,
    );
    expect(result, contains('✅ Synthetic completed task（締切 11/10）'));
    expect(result, contains('⬜️ Synthetic cached task（締切 11/20）'));
    expect(result.indexOf('Synthetic completed'),
        lessThan(result.indexOf('Synthetic cached')));
    expect(result, isNot(contains('Synthetic other month')));
    expect(result, isNot(contains('未取得')));
  });
}
