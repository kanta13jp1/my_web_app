import 'dart:typed_data';

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

    test('accepts pasted screenshot bytes for annual rate evidence', () async {
      Map<String, dynamic>? capturedBody;
      final service = AssetLiabilityAnnualRateEvidenceService(
        now: () => DateTime(2026, 5, 17, 12),
        chatService: AiHubChatService(
          invoker: (body) async {
            capturedBody = Map<String, dynamic>.from(body);
            return <String, dynamic>{
              'success': true,
              'verified': true,
              'status': 'verified',
              'detected_annual_rate': 0.145,
              'summary': '画面キャプチャに年利14.5%の記載があります。',
            };
          },
        ),
      );

      final evidence = await service.verifyEvidenceBytes(
        accountId: 'smbc_card_loan',
        accountName: '三井住友銀行カードローン',
        annualRate: 0.145,
        imageBytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/png',
        fileName: 'clipboard-annual-rate.png',
      );

      expect(evidence.status, AssetLiabilityAnnualRateEvidenceStatus.verified);
      expect(evidence.fileName, 'clipboard-annual-rate.png');
      expect(
        capturedBody?['action'],
        'asset_liability.verify_annual_rate_evidence',
      );
      expect(capturedBody?['imageBase64'], 'AQID');
      expect(capturedBody?['mimeType'], 'image/png');
      expect(capturedBody?['imageName'], 'clipboard-annual-rate.png');
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
      expect(evidence.summary, 'AIが年利証跡を確認できませんでした。');
      expect(evidence.errorMessage, contains('vision down'));
    });
  });
}
