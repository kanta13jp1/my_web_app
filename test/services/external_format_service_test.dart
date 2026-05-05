import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/external_format_service.dart';

void main() {
  group('ExternalFormatService', () {
    test('maps SSIM rows and excludes disabled fields', () {
      const service = ExternalFormatService();
      final profile = ExternalFormatService.defaultProfile('ssim');

      final result = service.transform(
        inputText: ExternalFormatService.sampleText('ssim'),
        profile: profile,
      );

      expect(result.warnings, isEmpty);
      expect(result.rows, hasLength(2));
      expect(result.outputFields, contains('carrier_code'));
      expect(result.outputFields, isNot(contains('aircraft_type')));
      expect(result.rows.first['carrier_code'], 'NH');
      expect(result.rows.first['flight_number'], '007');
    });

    test('reports required missing fields and exports selected targets', () {
      const service = ExternalFormatService();
      final profile = ExternalFormatService.defaultProfile('aidx').copyWith(
        mappings: const <ExternalFieldMapping>[
          ExternalFieldMapping(
            sourceField: 'MissingFlight',
            targetField: 'flight_id',
            requiredField: true,
          ),
          ExternalFieldMapping(
            sourceField: 'Status',
            targetField: 'status',
          ),
        ],
      );

      final result = service.transform(
        inputText: ExternalFormatService.sampleText('aidx'),
        profile: profile,
      );
      final exported = service.exportDelimited(result, profile.delimiter);

      expect(result.warnings.single, contains('Required source field'));
      expect(result.rows.first['flight_id'], isEmpty);
      expect(result.rows.first['status'], 'DELAYED');
      expect(exported.split('\n').first, 'flight_id,status');
    });
  });
}
