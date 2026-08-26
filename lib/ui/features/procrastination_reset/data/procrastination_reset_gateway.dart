import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/procrastination_reset_models.dart';

abstract class ProcrastinationResetGateway {
  Future<ProcrastinationResetSnapshot> load();

  Future<void> save(ProcrastinationResetSnapshot snapshot);
}

class SharedPreferencesProcrastinationResetGateway
    implements ProcrastinationResetGateway {
  SharedPreferencesProcrastinationResetGateway({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'procrastination_reset_snapshot_v1';

  final SharedPreferences? _preferences;

  @override
  Future<ProcrastinationResetSnapshot> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return const ProcrastinationResetSnapshot();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ProcrastinationResetSnapshot();
      return ProcrastinationResetSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      return const ProcrastinationResetSnapshot();
    }
  }

  @override
  Future<void> save(ProcrastinationResetSnapshot snapshot) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(snapshot.toJson()),
    );
    if (!saved) {
      throw StateError('先延ばしリセットの端末内保存に失敗しました。');
    }
  }
}
