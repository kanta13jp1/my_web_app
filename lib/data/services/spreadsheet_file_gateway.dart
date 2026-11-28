import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class SpreadsheetPickedCsv {
  const SpreadsheetPickedCsv({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class SpreadsheetFileGateway {
  Future<SpreadsheetPickedCsv?> pickCsv();
  Future<SpreadsheetPickedCsv?> pickXlsx();

  Future<bool> saveXlsx({
    required String suggestedName,
    required Uint8List bytes,
  });

  Future<bool> saveCsv({
    required String suggestedName,
    required Uint8List bytes,
  });
}

class FilePickerSpreadsheetFileGateway implements SpreadsheetFileGateway {
  const FilePickerSpreadsheetFileGateway();

  @override
  Future<SpreadsheetPickedCsv?> pickXlsx() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'XLSXを読み込む',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: false,
      withReadStream: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    const limit = 16 * 1024 * 1024;
    if (file.size > limit) throw const FormatException('XLSXは16MBまで対応しています。');
    final stream = file.readStream;
    if (stream == null) throw StateError('XLSXファイルを読み込めませんでした。');
    final content = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (content.length + chunk.length > limit) {
        throw const FormatException('XLSXは16MBまで対応しています。');
      }
      content.add(chunk);
    }
    return SpreadsheetPickedCsv(name: file.name, bytes: content.takeBytes());
  }

  @override
  Future<bool> saveXlsx({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'XLSXを別名で書き出す',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: bytes,
      lockParentWindow: true,
    );
    return kIsWeb || path != null;
  }

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
