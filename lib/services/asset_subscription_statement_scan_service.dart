import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_liability_workbook.dart';
import '../models/asset_subscription_statement_scan.dart';
import 'offline_secure_mode_settings_service.dart';

typedef AssetSubscriptionStatementInvoker = Future<Map<String, dynamic>>
    Function(Map<String, dynamic> body);

abstract interface class AssetSubscriptionStatementAnalyzer {
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  );
}

abstract interface class AssetSubscriptionStatementImagePicker {
  Future<List<AssetSubscriptionStatementImage>> pickImages();
}

const int assetSubscriptionStatementMaxImageCount = 5;

enum AssetSubscriptionStatementScanFailure { general, authenticationRequired }

class AssetSubscriptionStatementScanException implements Exception {
  final String message;
  final AssetSubscriptionStatementScanFailure failure;

  const AssetSubscriptionStatementScanException(
    this.message, {
    this.failure = AssetSubscriptionStatementScanFailure.general,
  });

  bool get requiresLogin =>
      failure == AssetSubscriptionStatementScanFailure.authenticationRequired;

  @override
  String toString() => message;
}

/// PNG/JPEG/WebP のカード明細キャプチャを最大5枚選択する。画像はファイル保存せず、
/// [PlatformFile.bytes] を解析サービスへ一度ずつ渡す。
class FilePickerAssetSubscriptionStatementImagePicker
    implements AssetSubscriptionStatementImagePicker {
  const FilePickerAssetSubscriptionStatementImagePicker();

  @override
  Future<List<AssetSubscriptionStatementImage>> pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return const <AssetSubscriptionStatementImage>[];
    if (files.length > assetSubscriptionStatementMaxImageCount) {
      throw const AssetSubscriptionStatementScanException('画像は一度に5枚まで選択できます。');
    }
    return <AssetSubscriptionStatementImage>[
      for (final file in files) _toStatementImage(file),
    ];
  }

  AssetSubscriptionStatementImage _toStatementImage(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null) {
      throw AssetSubscriptionStatementScanException(
        '${file.name}を読み込めませんでした。別の画像を選んでください。',
      );
    }
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
    return AssetSubscriptionStatementImage(
      fileName: file.name,
      mimeType: mimeType,
      bytes: Uint8List.fromList(bytes),
    );
  }
}

/// `ai-hub` の専用アクションを通じて明細画像を解析するサービス。
///
/// 画像はbase64で送信するだけで、Storage・DB・SharedPreferencesには保存しない。
/// サーバ側でPIIを除外した候補だけを返し、クライアントでも型・金額・件数を再検証する。
class AssetSubscriptionStatementScanService
    implements AssetSubscriptionStatementAnalyzer {
  static const int maxImageBytes = 4 * 1024 * 1024;
  static const int maxCandidates = 100;
  static const Set<String> allowedMimeTypes = <String>{
    'image/png',
    'image/jpeg',
    'image/webp',
  };

  final SupabaseClient? _supabase;
  final AssetSubscriptionStatementInvoker? _invoker;
  final OfflineSecureModeSettingsService _offlineSettingsService;

  const AssetSubscriptionStatementScanService({
    SupabaseClient? supabase,
    AssetSubscriptionStatementInvoker? invoker,
    OfflineSecureModeSettingsService offlineSettingsService =
        const OfflineSecureModeSettingsService(),
  })  : _supabase = supabase,
        _invoker = invoker,
        _offlineSettingsService = offlineSettingsService;

  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) async {
    _validateImage(image);
    if (_invoker == null) {
      final client = _supabase ?? Supabase.instance.client;
      if (client.auth.currentUser == null) {
        throw const AssetSubscriptionStatementScanException(
          '明細のAI解析にはログインが必要です。',
          failure: AssetSubscriptionStatementScanFailure.authenticationRequired,
        );
      }
    }

    final offline = await _offlineSettingsService.loadSettingsOrDefaults();
    final body = <String, dynamic>{
      'action': 'asset_subscription.analyze_statement',
      'imageBase64': base64Encode(image.bytes),
      'mimeType': image.mimeType,
      'imageName': _safeFileName(image.fileName),
      ...offline.toAiHubPolicyPayload(),
    };

    final data = await _invoke(body);
    if (data['success'] != true) {
      throw AssetSubscriptionStatementScanException(_failureMessage(data));
    }
    final rawCandidates = data['candidates'];
    if (rawCandidates is! List) return const [];
    final result = <AssetSubscriptionStatementCandidate>[];
    for (var i = 0;
        i < rawCandidates.length && result.length < maxCandidates;
        i++) {
      final raw = rawCandidates[i];
      if (raw is! Map) continue;
      final candidate = _candidateFromMap(Map<String, dynamic>.from(raw), i);
      if (candidate != null) result.add(candidate);
    }
    return result;
  }

  void _validateImage(AssetSubscriptionStatementImage image) {
    if (!allowedMimeTypes.contains(image.mimeType)) {
      throw const AssetSubscriptionStatementScanException(
        'PNG・JPEG・WebP形式の画像を選んでください。',
      );
    }
    if (image.bytes.isEmpty) {
      throw const AssetSubscriptionStatementScanException('画像が空です。');
    }
    if (image.bytes.length > maxImageBytes) {
      throw const AssetSubscriptionStatementScanException('画像は4MB以下にしてください。');
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke('ai-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'success': false, 'message': data?.toString()};
  }

  AssetSubscriptionStatementCandidate? _candidateFromMap(
    Map<String, dynamic> raw,
    int index,
  ) {
    final serviceName = _safeServiceName(raw['service_name']?.toString() ?? '');
    final amount = _asDouble(raw['amount_jpy']);
    if (serviceName.isEmpty ||
        amount == null ||
        amount <= 0 ||
        amount > 100000000) {
      return null;
    }
    final cycle = switch (raw['billing_cycle']?.toString()) {
      'monthly' => AssetSubscriptionBillingCycle.monthly,
      'annual' => AssetSubscriptionBillingCycle.annual,
      _ => AssetSubscriptionBillingCycle.unknown,
    };
    final gateway = switch (raw['gateway']?.toString()) {
      'apple' => AssetSubscriptionBillingGateway.apple,
      'googlePlay' => AssetSubscriptionBillingGateway.googlePlay,
      'auKantan' => AssetSubscriptionBillingGateway.auKantan,
      _ => AssetSubscriptionBillingGateway.direct,
    };
    final confidence = (_asDouble(raw['confidence']) ?? 0).clamp(0, 1);
    final chargedAt = DateTime.tryParse(raw['charged_at']?.toString() ?? '');
    final evidence = _stripSensitiveDigits(raw['evidence']?.toString() ?? '');
    return AssetSubscriptionStatementCandidate(
      id: 'statement_candidate_$index',
      serviceName: serviceName,
      chargedAmountJpy: amount,
      chargedAt: chargedAt,
      billingCycle: cycle,
      billingGateway: gateway,
      confidence: confidence.toDouble(),
      evidence: evidence.length <= 160 ? evidence : evidence.substring(0, 160),
    );
  }

  String _safeServiceName(String input) {
    final sanitized = _stripSensitiveDigits(
      input,
    ).replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    final trimmed = sanitized.trim();
    return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
  }

  String _stripSensitiveDigits(String input) {
    return input.replaceAll(RegExp(r'(?:\d[ -]?){12,19}'), '[番号を除外]');
  }

  String _safeFileName(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'[\r\n\\/]+'), '_');
    if (trimmed.isEmpty) return 'card-statement.png';
    return trimmed.length <= 120 ? trimmed : trimmed.substring(0, 120);
  }

  String _failureMessage(Map<String, dynamic> data) {
    final raw = <Object?>[data['message'], data['error'], data['status']]
        .map((value) => value?.toString().trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty);
    final joined = raw.join(' / ');
    if (joined.contains('offline')) {
      return 'オフライン保護モードでは外部AIへ画像を送信できません。';
    }
    if (RegExp(
      r'quota|429|rate.?limit',
      caseSensitive: false,
    ).hasMatch(joined)) {
      return 'AIの利用上限に達しました。時間をおいて再試行してください。';
    }
    return joined.isEmpty ? '明細画像を解析できませんでした。' : joined;
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
