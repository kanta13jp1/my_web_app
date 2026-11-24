import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/chord_lyrics_sheet.dart';

/// 端末ローカル専用のユーザー ChordPro 譜面保存ストレージ契約。
abstract interface class UserChordLyricsStorageService {
  Future<List<ChordLyricsSheetDocument>> loadSheets();

  Future<void> saveSheet(ChordLyricsSheetDocument sheet);

  Future<void> deleteSheet(String sheetId);
}

class SharedPreferencesUserChordLyricsStorageService
    implements UserChordLyricsStorageService {
  SharedPreferencesUserChordLyricsStorageService({
    SharedPreferences? preferences,
  }) : _preferences = preferences;

  static const String storageKey = 'guitar_user_chord_lyrics_v1';
  static const int maxStoredSheets = 30;
  static const int maxSourceBytes = 65536;

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _resolvePreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<List<ChordLyricsSheetDocument>> loadSheets() async {
    final prefs = await _resolvePreferences();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ChordLyricsSheetDocument>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const <ChordLyricsSheetDocument>[];
      }
      final result = <ChordLyricsSheetDocument>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(
            ChordLyricsSheetDocument.fromJson(
              item,
              isUserImported: true,
            ),
          );
        }
      }
      return result;
    } catch (_) {
      return const <ChordLyricsSheetDocument>[];
    }
  }

  @override
  Future<void> saveSheet(ChordLyricsSheetDocument sheet) async {
    final encodedSource = utf8.encode(sheet.sourceChordPro);
    if (encodedSource.length > maxSourceBytes) {
      throw const FormatException('64KB を超える ChordPro ファイルは保存できません。');
    }
    final existing = await loadSheets();
    final filtered = existing
        .where((ChordLyricsSheetDocument item) => item.id != sheet.id)
        .toList(growable: true);
    if (filtered.length >= maxStoredSheets) {
      throw const FormatException('ローカル保存できるマイ譜面は最大30件までです。');
    }
    final normalized = sheet.copyWith(isUserImported: true);
    filtered.insert(0, normalized);

    final prefs = await _resolvePreferences();
    final ok = await prefs.setString(
      storageKey,
      jsonEncode(
        filtered
            .map((ChordLyricsSheetDocument s) => s.toJson())
            .toList(growable: false),
      ),
    );
    if (!ok) {
      throw StateError('端末ストレージへの保存に失敗しました。');
    }
  }

  @override
  Future<void> deleteSheet(String sheetId) async {
    final existing = await loadSheets();
    final remaining = existing
        .where((ChordLyricsSheetDocument item) => item.id != sheetId)
        .toList(growable: false);
    final prefs = await _resolvePreferences();
    final ok = await prefs.setString(
      storageKey,
      jsonEncode(
        remaining
            .map((ChordLyricsSheetDocument s) => s.toJson())
            .toList(growable: false),
      ),
    );
    if (!ok) {
      throw StateError('端末ストレージの更新に失敗しました。');
    }
  }
}
