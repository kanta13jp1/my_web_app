import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/csv_bytes_decoder.dart';

void main() {
  test('uses UTF-8 when the decoded header is valid', () {
    final bytes = Uint8List.fromList(utf8.encode('銘柄コード,保有数量'));

    final decoded = const CsvBytesDecoder().decode(
      bytes,
      looksValid: (text) => text.contains('銘柄コード'),
      formatName: '投資資産CSV',
    );

    expect(decoded, '銘柄コード,保有数量');
  });

  test('uses the injected Shift_JIS decoder when UTF-8 is invalid', () {
    final bytes = Uint8List.fromList(const <int>[0x82, 0xa0]);
    final decoder = CsvBytesDecoder(shiftJisDecoder: (_) => '銘柄コード,保有数量');

    final decoded = decoder.decode(
      bytes,
      looksValid: (text) => text.contains('銘柄コード'),
      formatName: '投資資産CSV',
    );

    expect(decoded, '銘柄コード,保有数量');
  });

  test('rejects bytes when no decoded candidate has the expected header', () {
    final bytes = Uint8List.fromList(utf8.encode('unknown,data'));

    expect(
      () => const CsvBytesDecoder().decode(
        bytes,
        looksValid: (_) => false,
        formatName: '投資資産CSV',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '投資資産CSVの列名を判定できませんでした',
        ),
      ),
    );
  });
}
