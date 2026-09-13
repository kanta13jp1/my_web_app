import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/custom_task_list.dart';

abstract class CustomTaskListStore {
  Future<CustomTaskListSnapshot?> load();

  Future<void> save(CustomTaskListSnapshot snapshot);
}

class SharedPreferencesCustomTaskListStore implements CustomTaskListStore {
  static const storageKey = 'custom_task_list.snapshot.v1';

  const SharedPreferencesCustomTaskListStore();

  @override
  Future<CustomTaskListSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CustomTaskListSnapshot.fromJson(decoded);
      }
      if (decoded is Map) {
        return CustomTaskListSnapshot.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Future<void> save(CustomTaskListSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(snapshot.toJson()));
  }
}
