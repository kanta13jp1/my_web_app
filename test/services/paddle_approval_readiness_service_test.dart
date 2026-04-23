import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/paddle_approval_readiness_service.dart';

void main() {
  group('PaddleApprovalReadinessService', () {
    const service = PaddleApprovalReadinessService();

    test('buildReport returns the expected baseline checklist counts', () {
      final report = service.buildReport();

      expect(report.sections.length, 5);
      expect(report.totalItems, 19);
      expect(report.criticalItems, 15);
      expect(report.hiddenItems, 4);
      expect(report.primaryActions, hasLength(3));
    });

    test('buildReport surfaces regulated data warning when requested', () {
      final report = service.buildReport(touchesRegulatedData: true);

      expect(report.regulatedDataWarning, isNotNull);
      expect(report.regulatedDataWarning, contains('個人情報'));
    });
  });
}
