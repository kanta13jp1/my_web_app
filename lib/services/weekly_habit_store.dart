import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_habit.dart';

/// Device/browser-local only. User IDs isolate accounts on shared browsers.
class WeeklyHabitStore {
  WeeklyHabitStore(this.preferences, {required String userId})
      : key = 'asset_weekly_habits_v1_$userId';

  final SharedPreferences preferences;
  final String key;

  WeeklyHabitState load() {
    final saved = preferences.getString(key);
    if (saved == null) return WeeklyHabitState.initial();
    // Surface malformed storage; never silently overwrite it with defaults.
    final decoded = jsonDecode(saved);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid weekly habit data');
    }
    return WeeklyHabitState.fromJson(decoded);
  }

  Future<void> save(WeeklyHabitState state) async {
    final saved = await preferences.setString(key, jsonEncode(state.toJson()));
    if (!saved) throw StateError('Weekly habit save failed');
  }
}
