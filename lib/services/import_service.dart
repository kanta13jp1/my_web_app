import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import '../utils/app_logger.dart';
import 'gamification_service.dart';

/// NotionやEvernoteからメモをインポートするサービス
class ImportService {
  final SupabaseClient _supabase;
  final GamificationService _gamificationService;

  ImportService(this._supabase)
      : _gamificationService = GamificationService(_supabase);

  /// Notion CSVファイルをパース（タイトル、内容、作成日、更新日）
  Future<List<Map<String, dynamic>>> parseNotionCsv(String csvContent) async {
    try {
      final lines = csvContent.split('\n');
      if (lines.isEmpty) return [];

      // ヘッダー行を解析
      final headers = _parseCsvLine(lines[0]);
      final titleIndex = headers.indexWhere((h) =>
          h.toLowerCase().contains('title') ||
          h.toLowerCase().contains('name'));
      final contentIndex = headers.indexWhere(
          (h) => h.toLowerCase().contains('content') || h.toLowerCase().contains('body'));
      final createdIndex = headers
          .indexWhere((h) => h.toLowerCase().contains('created'));
      final updatedIndex = headers
          .indexWhere((h) => h.toLowerCase().contains('updated') || h.toLowerCase().contains('modified'));

      final List<Map<String, dynamic>> parsedNotes = [];

      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        final fields = _parseCsvLine(lines[i]);
        if (fields.isEmpty) continue;

        final title = titleIndex >= 0 && titleIndex < fields.length
            ? fields[titleIndex]
            : 'Untitled';
        final content = contentIndex >= 0 && contentIndex < fields.length
            ? fields[contentIndex]
            : '';
        final created = createdIndex >= 0 && createdIndex < fields.length
            ? _parseDate(fields[createdIndex])
            : DateTime.now();
        final updated = updatedIndex >= 0 && updatedIndex < fields.length
            ? _parseDate(fields[updatedIndex])
            : created;

        parsedNotes.add({
          'title': title,
          'content': content,
          'created_at': created.toIso8601String(),
          'updated_at': updated.toIso8601String(),
        });
      }

      return parsedNotes;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing Notion CSV', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Evernote ENEX (XML) ファイルをパース
  Future<List<Map<String, dynamic>>> parseEvernoteEnex(String enexContent) async {
    try {
      final List<Map<String, dynamic>> parsedNotes = [];

      // シンプルなXMLパーサー（<note>タグを検索）
      final noteMatches = RegExp(r'<note>(.*?)</note>', dotAll: true).allMatches(enexContent);

      for (final match in noteMatches) {
        final noteXml = match.group(1) ?? '';

        final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(noteXml);
        final contentMatch = RegExp(r'<content>(.*?)</content>', dotAll: true).firstMatch(noteXml);
        final createdMatch = RegExp(r'<created>(.*?)</created>').firstMatch(noteXml);
        final updatedMatch = RegExp(r'<updated>(.*?)</updated>').firstMatch(noteXml);

        final title = titleMatch?.group(1) ?? 'Untitled';
        var content = contentMatch?.group(1) ?? '';

        // CDATA セクションを削除
        content = content.replaceAll(RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true), r'$1');
        // HTMLタグを削除（簡易的）
        content = content.replaceAll(RegExp(r'<[^>]*>'), '');
        // エンティティをデコード
        content = _decodeHtmlEntities(content);

        final created = createdMatch != null
            ? _parseEvernoteDate(createdMatch.group(1)!)
            : DateTime.now();
        final updated = updatedMatch != null
            ? _parseEvernoteDate(updatedMatch.group(1)!)
            : created;

        parsedNotes.add({
          'title': title,
          'content': content,
          'created_at': created.toIso8601String(),
          'updated_at': updated.toIso8601String(),
        });
      }

      return parsedNotes;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing Evernote ENEX', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Markdown形式のファイルをパース（汎用インポート）
  Future<List<Map<String, dynamic>>> parseMarkdown(String markdownContent) async {
    try {
      final List<Map<String, dynamic>> parsedNotes = [];

      // # や ## で始まる行をタイトルとして認識
      final sections = markdownContent.split(RegExp(r'^#{1,2}\s+', multiLine: true));

      for (var i = 1; i < sections.length; i++) {
        final section = sections[i].trim();
        if (section.isEmpty) continue;

        final lines = section.split('\n');
        final title = lines.first.trim();
        final content = lines.skip(1).join('\n').trim();

        parsedNotes.add({
          'title': title,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // セクション分けされていない場合は全体を1つのメモとして扱う
      if (parsedNotes.isEmpty) {
        parsedNotes.add({
          'title': 'Imported Note',
          'content': markdownContent,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return parsedNotes;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing Markdown', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// インポートしたメモをデータベースに保存
  Future<int> importNotes({
    required String userId,
    required List<Map<String, dynamic>> notes,
    String? categoryId,
  }) async {
    try {
      int importedCount = 0;

      for (final noteData in notes) {
        try {
          await _supabase.from('notes').insert({
            'user_id': userId,
            'title': noteData['title'],
            'content': noteData['content'],
            'category_id': categoryId,
            'created_at': noteData['created_at'],
            'updated_at': noteData['updated_at'],
            'is_favorite': false,
            'is_pinned': false,
            'is_archived': false,
          });

          importedCount++;
        } catch (e) {
          AppLogger.warning('Failed to import individual note: ${noteData['title']}', error: e);
        }
      }

      // インポート成功ボーナス
      if (importedCount > 0) {
        await _awardImportBonus(userId, importedCount);
      }

      return importedCount;
    } catch (e, stackTrace) {
      AppLogger.error('Error importing notes', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// インポートボーナスを付与
  Future<void> _awardImportBonus(String userId, int importedCount) async {
    try {
      // インポート数に応じてボーナスポイントを付与
      final bonusPoints = importedCount * 10; // 1メモあたり10ポイント

      await _gamificationService.awardPoints(
        userId,
        bonusPoints,
        reason: 'Notion/Evernoteからのインポート',
      );

      AppLogger.info('Import bonus awarded: $bonusPoints points for $importedCount notes');
    } catch (e, stackTrace) {
      AppLogger.error('Error awarding import bonus', error: e, stackTrace: stackTrace);
    }
  }

  /// CSV行をパース（カンマ区切り、ダブルクォート対応）
  List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField.toString().trim());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }

    fields.add(currentField.toString().trim());
    return fields;
  }

  /// 日付文字列をパース（様々な形式に対応）
  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      // パースに失敗した場合は現在時刻を返す
      return DateTime.now();
    }
  }

  /// Evernote形式の日付をパース（例: 20231201T120000Z）
  DateTime _parseEvernoteDate(String dateStr) {
    try {
      // 基本的なISO 8601形式
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      }

      // Evernote形式: 20231201T120000Z
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      final hour = int.parse(dateStr.substring(9, 11));
      final minute = int.parse(dateStr.substring(11, 13));
      final second = int.parse(dateStr.substring(13, 15));

      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// HTMLエンティティをデコード
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
