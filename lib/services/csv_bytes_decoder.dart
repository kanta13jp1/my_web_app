import 'dart:convert';
import 'dart:typed_data';

import 'csv_shift_jis_decoder_stub.dart'
    if (dart.library.js_interop) 'csv_shift_jis_decoder_web.dart';

typedef CsvTextValidator = bool Function(String text);
typedef CsvLegacyDecoder = String? Function(Uint8List bytes);

/// Decodes Japanese CSV exports without coupling the encoding fallback to a
/// specific bank or broker header.
class CsvBytesDecoder {
  const CsvBytesDecoder({CsvLegacyDecoder? shiftJisDecoder})
      : _shiftJisDecoder = shiftJisDecoder;

  final CsvLegacyDecoder? _shiftJisDecoder;

  String decode(
    Uint8List bytes, {
    required CsvTextValidator looksValid,
    required String formatName,
  }) {
    try {
      final text = utf8.decode(bytes);
      if (looksValid(text)) return text;
    } on FormatException {
      // Japanese broker and bank exports are often CP932/Shift_JIS.
    }

    try {
      final text = (_shiftJisDecoder ?? decodeShiftJis)(bytes);
      if (text != null && looksValid(text)) return text;
    } on Object {
      // Continue to the malformed UTF-8 check so callers receive one error.
    }

    final malformed = utf8.decode(bytes, allowMalformed: true);
    if (looksValid(malformed)) return malformed;
    throw FormatException('$formatNameの列名を判定できませんでした');
  }
}
