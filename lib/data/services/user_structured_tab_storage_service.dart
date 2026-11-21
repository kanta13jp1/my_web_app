import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/structured_guitar_tab.dart';

/// ユーザー自身が持ち込んだ構造化TAB譜の端末ローカル保存インターフェース。
/// 私的練習用の非公開ストレージであり、サーバー送信・公開共有は行いません。
abstract interface class UserStructuredTabStorageService {
  Future<List<StructuredGuitarTabScore>> loadScores();

  Future<void> saveScore(StructuredGuitarTabScore score);

  Future<void> deleteScore(String id);
}

class SharedPreferencesUserStructuredTabStorageService
    implements UserStructuredTabStorageService {
  SharedPreferencesUserStructuredTabStorageService({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance;

  static const String storageKey = 'my_web_app.user_structured_tabs.v1';

  final Future<SharedPreferences> Function() _preferencesProvider;

  @override
  Future<List<StructuredGuitarTabScore>> loadScores() async {
    final prefs = await _preferencesProvider();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <StructuredGuitarTabScore>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <StructuredGuitarTabScore>[];
      }
      final result = <StructuredGuitarTabScore>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = <String, Object?>{};
        for (final entry in item.entries) {
          map[entry.key.toString()] = entry.value;
        }
        try {
          result.add(
            StructuredGuitarTabScore.fromJson(map, forceUserImported: true),
          );
        } on FormatException {
          // 破損した個別レコードは安全にスキップする。
        }
      }
      return List<StructuredGuitarTabScore>.unmodifiable(result);
    } on FormatException {
      return const <StructuredGuitarTabScore>[];
    }
  }

  @override
  Future<void> saveScore(StructuredGuitarTabScore score) async {
    final normalized = score.copyWith(
      isOriginalPractice: false,
      isUserImported: true,
    );
    final current = await loadScores();
    final updated = <StructuredGuitarTabScore>[
      normalized,
      for (final existing in current)
        if (existing.id != normalized.id) existing,
    ];
    await _persistList(updated);
  }

  @override
  Future<void> deleteScore(String id) async {
    final current = await loadScores();
    final updated = current
        .where((StructuredGuitarTabScore score) => score.id != id)
        .toList();
    await _persistList(updated);
  }

  Future<void> _persistList(List<StructuredGuitarTabScore> scores) async {
    final prefs = await _preferencesProvider();
    final payload =
        scores.map((StructuredGuitarTabScore score) => score.toJson()).toList();
    await prefs.setString(storageKey, jsonEncode(payload));
  }
}
