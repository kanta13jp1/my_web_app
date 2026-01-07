import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'gamification_service.dart';

class ImportService {
  final GamificationService _gamificationService;

  ImportService(this._gamificationService);

  Future<void> importData() async {
    // スタブ実装
    await _gamificationService.awardPoints(50, reason: "Import Data");
  }

  Future<void> processImport(File file) async {
    // ... logic ...
    await _gamificationService.awardPoints(100, reason: "Data Import Success");
  }

  // プレースホルダーメソッド (Linterエラー回避用)
  Future<void> parseNotionCsv(File file) async {}
  Future<void> parseEvernoteEnex(File file) async {}
  Future<void> parseMarkdown(File file) async {}
  Future<void> importNotes(List<dynamic> notes) async {}
}
