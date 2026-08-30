import 'dart:convert';

import '../../domain/models/spreadsheet_document.dart';
import '../services/spreadsheet_local_storage_service.dart';

abstract interface class SpreadsheetRepository {
  Future<SpreadsheetDocument?> load();

  Future<void> save(SpreadsheetDocument document);
}

class LocalSpreadsheetRepository implements SpreadsheetRepository {
  const LocalSpreadsheetRepository({required this.storageService});

  final SpreadsheetLocalStorageService storageService;

  @override
  Future<SpreadsheetDocument?> load() async {
    final encoded = await storageService.read();
    if (encoded == null || encoded.trim().isEmpty) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid spreadsheet document.');
    }
    return SpreadsheetDocument.fromJson(decoded);
  }

  @override
  Future<void> save(SpreadsheetDocument document) {
    return storageService.write(jsonEncode(document.toJson()));
  }
}
