import 'dart:io';
import 'gamification_service.dart';

class ImportService {
  final GamificationService _gamificationService;

  ImportService(this._gamificationService);

  Future<void> importData() async {
    await _gamificationService.awardPoints(50, reason: "Import Data");
  }

  Future<void> processImport(File file) async {
    await _gamificationService.awardPoints(100, reason: "Data Import Success");
  }

  // スタブメソッド (エラー回避用)
  Future<void> parseNotionCsv(File file) async {}
  Future<void> parseEvernoteEnex(File file) async {}
  Future<void> parseMarkdown(File file) async {}

  // 修正: 名前付き引数を受け取るように変更
  Future<void> importNotes({
    required String userId,
    required List<dynamic> notes,
    required String categoryId,
  }) async {
    // インポート処理ロジック (スタブ)
    await _gamificationService.awardPoints(10 * notes.length,
        reason: "Imported ${notes.length} notes");
  }
}
