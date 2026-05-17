import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_liability_annual_rate_evidence_service.dart';

void main() {
  group('AssetLiabilityAnnualRateEvidenceService', () {
    test('stores verified AI evidence for matching annual rate', () async {
      final service = AssetLiabilityAnnualRateEvidenceService(
        now: () => DateTime(2026, 5, 17, 12),
        chatService: AiHubChatService(
          invoker: (_) async => <String, dynamic>{
            'success': true,
            'verified': true,
            'status': 'verified',
            'detected_annual_rate': 0.18,
            'summary': 'The screenshot shows 18.0% annual rate.',
          },
        ),
      );

      final evidence = await service.verifyEvidence(
        accountId: 'mobit',
        accountName: 'Mobit',
        annualRate: 0.18,
        imageBase64: 'abc',
        mimeType: 'image/png',
        fileName: 'mobit_apr.png',
      );

      expect(evidence.status, AssetLiabilityAnnualRateEvidenceStatus.verified);
      expect(evidence.verified, isTrue);
      expect(evidence.matchesAnnualRate(0.18), isTrue);
      expect(evidence.fileName, 'mobit_apr.png');
    });

    test('keeps failed evidence without approving annual rate', () async {
      final service = AssetLiabilityAnnualRateEvidenceService(
        now: () => DateTime(2026, 5, 17, 12),
        chatService: AiHubChatService(
          invoker: (_) async => throw const AiHubChatException('vision down'),
        ),
      );

      final evidence = await service.verifyEvidence(
        accountId: 'mobit',
        accountName: 'Mobit',
        annualRate: 0.18,
        imageBase64: 'abc',
        mimeType: 'image/png',
        fileName: 'mobit_apr.png',
      );

      expect(evidence.status, AssetLiabilityAnnualRateEvidenceStatus.failed);
      expect(evidence.verified, isFalse);
      expect(evidence.matchesAnnualRate(0.18), isFalse);
      expect(evidence.errorMessage, contains('vision down'));
    });
  });
}
