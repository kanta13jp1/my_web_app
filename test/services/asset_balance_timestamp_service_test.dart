import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_balance_timestamp_service.dart';

void main() {
  group('AssetBalanceTimestampService', () {
    test('encodes local instants as UTC with an explicit zone', () {
      final encoded = AssetBalanceTimestampService.encodeForDatabase(
        DateTime(2026, 8, 23, 16, 42),
      );

      expect(encoded, endsWith('Z'));
      expect(DateTime.parse(encoded).isUtc, isTrue);
    });

    test('clamps a legacy next-day future timestamp to today', () {
      final recordDate = AssetBalanceTimestampService.localRecordDate(
        DateTime(2026, 8, 24, 1, 42),
        now: DateTime(2026, 8, 23, 17),
      );

      expect(recordDate, DateTime(2026, 8, 23));
    });

    test('keeps valid past record dates unchanged', () {
      final recordDate = AssetBalanceTimestampService.localRecordDate(
        DateTime(2026, 8, 22, 23, 59),
        now: DateTime(2026, 8, 23, 17),
      );

      expect(recordDate, DateTime(2026, 8, 22));
    });
  });
}
