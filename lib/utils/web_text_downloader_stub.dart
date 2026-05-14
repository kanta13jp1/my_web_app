import 'package:flutter/foundation.dart';

void downloadTextFile(
  String textData,
  String fileName, {
  String mimeType = 'text/plain;charset=utf-8',
}) {
  debugPrint('Web text download is not supported on this platform: $fileName');
}
