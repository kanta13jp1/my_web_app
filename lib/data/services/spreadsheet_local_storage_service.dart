import 'package:shared_preferences/shared_preferences.dart';

class SpreadsheetLocalStorageService {
  const SpreadsheetLocalStorageService({
    this.storageKey = 'spreadsheet_mvp_document_v1',
  });

  final String storageKey;

  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(storageKey);
  }

  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setString(storageKey, value);
    if (!stored) {
      throw StateError('Could not persist the spreadsheet document.');
    }
  }
}
