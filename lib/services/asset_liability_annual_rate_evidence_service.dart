import 'dart:convert';
import 'dart:typed_data';

import 'package:my_web_app/models/asset_liability_workbook.dart';

import 'ai_hub_chat_service.dart';

class AssetLiabilityAnnualRateEvidenceService {
  final AiHubChatService _chatService;
  final DateTime Function() _now;

  AssetLiabilityAnnualRateEvidenceService({
    AiHubChatService chatService = const AiHubChatService(),
    DateTime Function()? now,
  })  : _chatService = chatService,
        _now = now ?? DateTime.now;

  Future<AssetLiabilityAnnualRateEvidence> verifyEvidenceBytes({
    required String accountId,
    required String accountName,
    required double annualRate,
    required Uint8List imageBytes,
    required String mimeType,
    required String fileName,
  }) {
    return verifyEvidence(
      accountId: accountId,
      accountName: accountName,
      annualRate: annualRate,
      imageBase64: base64Encode(imageBytes),
      mimeType: mimeType,
      fileName: fileName,
    );
  }

  Future<AssetLiabilityAnnualRateEvidence> verifyEvidence({
    required String accountId,
    required String accountName,
    required double annualRate,
    required String imageBase64,
    required String mimeType,
    required String fileName,
  }) async {
    try {
      final response = await _chatService.verifyAnnualRateEvidence(
        accountName: accountName,
        submittedAnnualRate: annualRate,
        imageBase64: imageBase64,
        mimeType: mimeType,
        imageName: fileName,
        traceId: 'asset-liability-annual-rate-evidence',
      );
      return AssetLiabilityAnnualRateEvidence(
        accountId: accountId,
        fileName: fileName,
        mimeType: mimeType,
        submittedAt: _now(),
        submittedAnnualRate: annualRate,
        detectedAnnualRate: response.detectedAnnualRate,
        status: response.verified
            ? AssetLiabilityAnnualRateEvidenceStatus.verified
            : AssetLiabilityAnnualRateEvidenceStatus.needsReview,
        summary: response.summary,
        source: response.source,
      );
    } catch (error) {
      return AssetLiabilityAnnualRateEvidence(
        accountId: accountId,
        fileName: fileName,
        mimeType: mimeType,
        submittedAt: _now(),
        submittedAnnualRate: annualRate,
        detectedAnnualRate: null,
        status: AssetLiabilityAnnualRateEvidenceStatus.failed,
        summary: 'AIが年利証跡を確認できませんでした。',
        source: 'ai-hub asset_liability.verify_annual_rate_evidence',
        errorMessage: error.toString(),
      );
    }
  }
}
