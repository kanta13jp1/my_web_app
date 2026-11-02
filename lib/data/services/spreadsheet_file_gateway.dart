import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class SpreadsheetPickedCsv {
  const SpreadsheetPickedCsv({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class SpreadsheetFileGateway {
  Future<SpreadsheetPickedCsv?> pickCsv();

  Future<bool> saveCsv({
    required String suggestedName,
    required Uint8List bytes,
  });
}

class FilePickerSpreadsheetFileGateway implements SpreadsheetFileGateway {
  const FilePickerSpreadsheetFileGateway();

  @override
  Future<SpreadsheetPickedCsv?> pickCsv() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'CSVを読み込む',
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      withData: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) throw StateError('CSVファイルを読み込めませんでした。');
    return SpreadsheetPickedCsv(name: file.name, bytes: bytes);
  }

  @override
  Future<bool> saveCsv({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'CSVを書き出す',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      bytes: bytes,
      lockParentWindow: true,
    );
    return kIsWeb || path != null;
  }
}
