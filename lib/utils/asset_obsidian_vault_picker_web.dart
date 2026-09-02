import 'dart:async';
import 'dart:js_interop';

import 'package:my_web_app/models/asset_obsidian_vault_import.dart';
import 'package:web/web.dart' as web;

const int _maxMarkdownFileCount = 2000;
const int _maxFileBytes = 2 * 1024 * 1024;
const int _maxTotalBytes = 10 * 1024 * 1024;

bool get isAssetObsidianVaultPickerSupported => true;

Future<AssetObsidianVaultSelection?> pickAssetObsidianVault() {
  final completer = Completer<AssetObsidianVaultSelection?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.md,text/markdown,text/plain'
    ..multiple = true
    ..webkitdirectory = true
    ..style.display = 'none';

  void finish(AssetObsidianVaultSelection? selection) {
    if (completer.isCompleted) return;
    input.remove();
    completer.complete(selection);
  }

  void fail(Object error, StackTrace stackTrace) {
    if (completer.isCompleted) return;
    input.remove();
    completer.completeError(error, stackTrace);
  }

  Future<void> readSelection() async {
    try {
      final fileList = input.files;
      if (fileList == null || fileList.length == 0) {
        finish(null);
        return;
      }

      final markdownFiles = <web.File>[];
      var totalBytes = 0;
      String? vaultName;
      for (var index = 0; index < fileList.length; index++) {
        final file = fileList.item(index);
        if (file == null) continue;
        final relativePath = file.webkitRelativePath.replaceAll('\\', '/');
        final segments = relativePath.split('/');
        if (vaultName == null && segments.isNotEmpty) {
          vaultName = segments.first;
        }
        if (!relativePath.toLowerCase().endsWith('.md') ||
            segments.any((segment) => segment == '.obsidian')) {
          continue;
        }
        if (file.size > _maxFileBytes) {
          throw AssetObsidianVaultPickerException(
            '${file.name} は2MBを超えるため読み込めません。',
          );
        }
        markdownFiles.add(file);
        totalBytes += file.size;
      }

      if (markdownFiles.length > _maxMarkdownFileCount) {
        throw const AssetObsidianVaultPickerException(
          'Markdownファイルが2,000件を超えています。対象を分けて選択してください。',
        );
      }
      if (totalBytes > _maxTotalBytes) {
        throw const AssetObsidianVaultPickerException(
          'Markdownファイルの合計が10MBを超えています。対象を分けて選択してください。',
        );
      }

      final selectedFiles = <AssetObsidianVaultFile>[];
      for (final file in markdownFiles) {
        final content = (await file.text().toDart).toDart;
        selectedFiles.add(
          AssetObsidianVaultFile(
            relativePath: file.webkitRelativePath.replaceAll('\\', '/'),
            content: content,
            byteSize: file.size,
            lastModified: DateTime.fromMillisecondsSinceEpoch(
              file.lastModified,
            ),
          ),
        );
      }
      finish(
        AssetObsidianVaultSelection(
          vaultName: vaultName?.trim().isNotEmpty == true
              ? vaultName!.trim()
              : '選択した保管庫',
          files: selectedFiles,
        ),
      );
    } catch (error, stackTrace) {
      fail(error, stackTrace);
    }
  }

  input.onchange = ((web.Event _) {
    unawaited(readSelection());
  }).toJS;
  input.oncancel = ((web.Event _) {
    finish(null);
  }).toJS;
  web.document.body?.append(input);
  input.click();
  return completer.future;
}
