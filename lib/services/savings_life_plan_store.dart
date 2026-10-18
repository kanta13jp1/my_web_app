import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/savings_life_plan.dart';

/// Separate, user-scoped planning data. No financial repository or network writes.
class SavingsLifePlanStore {
  SavingsLifePlanStore(this.userId);
  final String userId;
  String get _key => 'savings_life_plan_v1:$userId';
  String _dailyKey(DateTime day) =>
      '$_key:daily:${SavingsLifePlan.dateText(day)}';

  Future<SavingsLifePlan?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    return SavingsLifePlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(SavingsLifePlan plan) async {
    final ok = await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(plan.toJson()));
    if (!ok) throw StateError('plan save failed');
  }

  Future<Set<String>> loadDaily(DateTime day) async {
    return (await SharedPreferences.getInstance())
            .getStringList(_dailyKey(day))
            ?.toSet() ??
        <String>{};
  }

  Future<void> saveDaily(DateTime day, Set<String> values) async {
    final ok = await (await SharedPreferences.getInstance())
        .setStringList(_dailyKey(day), values.toList()..sort());
    if (!ok) throw StateError('daily save failed');
  }
}
