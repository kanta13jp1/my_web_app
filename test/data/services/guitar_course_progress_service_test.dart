import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/guitar_daily_course_model.dart';
import 'package:my_web_app/data/services/guitar_course_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists guitar course tasks, days, and practice dates', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final service = SharedPreferencesGuitarCourseProgressService(
      preferences: preferences,
    );

    await service.save(
      const GuitarCourseProgressModel(
        completedTaskIds: <String>['d01-posture', 'd01-tune'],
        completedDayNumbers: <int>[1, 2],
        practiceDateKeys: <String>['2026-08-12', '2026-08-13'],
      ),
    );
    final restored = await service.load();

    expect(restored.completedTaskIds, <String>['d01-posture', 'd01-tune']);
    expect(restored.completedDayNumbers, <int>[1, 2]);
    expect(restored.practiceDateKeys, <String>['2026-08-12', '2026-08-13']);
  });
}
