import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/smbc_csv_import_service.dart';

void main() {
  group('SmbcCsvImportService', () {
    test('parses withdrawals and deposits from SMBC CSV', () {
      const csv = '''
年月日,お引出し,お預入れ,お取り扱い内容,残高,メモ,ラベル
2026/4/29,26210,,"FAMIPAY",191103,"",
2026/4/27,,990,"振込 ニッポンチュウオウケイバカイ",287313,"競馬払戻","income"
''';

      final result = const SmbcCsvImportService().parse(csv);

      expect(result.transactions, hasLength(2));
      expect(result.withdrawalCount, 1);
      expect(result.depositCount, 1);
      expect(result.latestBalance, 191103);
      expect(result.transactions.first.actionType, 'expense');
      expect(result.transactions.first.displayMemo, 'FAMIPAY');
      expect(result.transactions.last.actionType, 'conquer');
      expect(
        result.transactions.last.displayMemo,
        '振込 ニッポンチュウオウケイバカイ / 競馬払戻 / income',
      );
    });

    test('keeps duplicate-looking rows by assigning stable ordinals', () {
      const csv = '''
年月日,お引出し,お預入れ,お取り扱い内容,残高,メモ,ラベル
2026/4/29,500,,"コンビニ",10000,"",
2026/4/29,500,,"コンビニ",9500,"",
2026/4/29,500,,"コンビニ",9500,"",
''';

      final result = const SmbcCsvImportService().parse(csv);

      expect(result.transactions, hasLength(3));
      expect(
        result.transactions.map((item) => item.importKey).toSet(),
        hasLength(3),
      );
    });
  });
}
