import 'package:shared_preferences/shared_preferences.dart';

import '../models/guitar_daily_course_model.dart';

abstract interface class GuitarCourseProgressService {
  Future<GuitarCourseProgressModel> load();

  Future<void> save(GuitarCourseProgressModel progress);
}

class SharedPreferencesGuitarCourseProgressService
    implements GuitarCourseProgressService {
  SharedPreferencesGuitarCourseProgressService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String _taskIdsKey = 'guitar_course_v1_completed_task_ids';
  static const String _dayNumbersKey = 'guitar_course_v1_completed_day_numbers';
  static const String _practiceDatesKey = 'guitar_course_v1_practice_dates';

  final SharedPreferences? _preferences;

  @override
  Future<GuitarCourseProgressModel> load() async {
    final preferences = await _resolvePreferences();
    return GuitarCourseProgressModel(
      completedTaskIds:
          preferences.getStringList(_taskIdsKey) ?? const <String>[],
      completedDayNumbers:
          (preferences.getStringList(_dayNumbersKey) ?? const <String>[])
              .map(int.tryParse)
              .whereType<int>()
              .toList(growable: false),
      practiceDateKeys:
          preferences.getStringList(_practiceDatesKey) ?? const <String>[],
    );
  }

  @override
  Future<void> save(GuitarCourseProgressModel progress) async {
    final preferences = await _resolvePreferences();
    final dayNumbers = progress.completedDayNumbers
        .map((number) => number.toString())
        .toList(growable: false);
    await Future.wait(<Future<bool>>[
      preferences.setStringList(_taskIdsKey, progress.completedTaskIds),
      preferences.setStringList(_dayNumbersKey, dayNumbers),
      preferences.setStringList(_practiceDatesKey, progress.practiceDateKeys),
    ]);
  }

  Future<SharedPreferences> _resolvePreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }
}
