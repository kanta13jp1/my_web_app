import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/palm_reading.dart';
import '../../domain/palm_reading_exception.dart';
import '../../services/offline_secure_mode_settings_service.dart';
import '../models/palm_reading_image.dart';

typedef PalmReadingActionInvoker = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> body);
typedef PalmReadingHistoryLoader = Future<List<Map<String, dynamic>>> Function(
    int limit);
typedef PalmReadingImageSigner = Future<String?> Function(String imagePath);

abstract interface class PalmReadingRepository {
  Future<PalmReading> analyze({
    required PalmReadingImage image,
    required PalmHandSide handSide,
  });

  Future<List<PalmReading>> loadHistory({int limit = 50});

  Future<void> deleteReading(String readingId);
}

class SupabasePalmReadingRepository implements PalmReadingRepository {
  SupabasePalmReadingRepository({
    SupabaseClient? client,
    PalmReadingActionInvoker? invoker,
    PalmReadingHistoryLoader? historyLoader,
    PalmReadingImageSigner? imageSigner,
    OfflineSecureModeSettingsService offlineSettingsService =
        const OfflineSecureModeSettingsService(),
    Uuid uuid = const Uuid(),
  })  : _client = client,
        _invoker = invoker,
        _historyLoader = historyLoader,
        _imageSigner = imageSigner,
        _offlineSettingsService = offlineSettingsService,
        _uuid = uuid;

  static const String tableName = 'palm_readings';
  static const String bucketName = 'palm-readings';
  static const int maxImageBytes = 4 * 1024 * 1024;
  static const Set<String> allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final SupabaseClient? _client;
  final PalmReadingActionInvoker? _invoker;
  final PalmReadingHistoryLoader? _historyLoader;
  final PalmReadingImageSigner? _imageSigner;
  final OfflineSecureModeSettingsService _offlineSettingsService;
  final Uuid _uuid;

  @override
  Future<PalmReading> analyze({
    required PalmReadingImage image,
    required PalmHandSide handSide,
  }) async {
    _validateImage(image);
    _requireUserWhenUsingSupabase();
    final offline = await _offlineSettingsService.loadSettingsOrDefaults();
    final data = await _invoke(<String, dynamic>{
      'action': 'palm_reading.analyze',
      'request_id': _uuid.v4(),
      'hand_side': handSide.wireValue,
      'imageName': image.fileName,
      'mimeType': image.mimeType,
      'imageBase64': base64Encode(image.bytes),
      ...offline.toAiHubPolicyPayload(),
    });
    if (data['success'] != true) {
      throw PalmReadingException(
        _failureMessage(data),
        code: data['status']?.toString(),
      );
    }
    final readingJson = _mapFrom(data['reading']);
    if (readingJson.isEmpty) {
      throw const PalmReadingException(
        'AI鑑定結果を読み込めませんでした。',
        code: 'invalidResponse',
      );
    }
    return PalmReading.fromJson(readingJson);
  }

  @override
  Future<List<PalmReading>> loadHistory({int limit = 50}) async {
    final safeLimit = limit.clamp(1, 100);
    final loader = _historyLoader;
    List<Map<String, dynamic>> rows;
    if (loader != null) {
      rows = await loader(safeLimit);
    } else {
      final client = _resolvedClient();
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const <PalmReading>[];
      final rawRows = await client
          .from(tableName)
          .select(
            'id,request_id,hand_side,image_path,image_mime_type,analysis,'
            'comparison,provider,model,schema_version,quality_score,created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(safeLimit);
      rows = rawRows.map(_mapFrom).toList(growable: false);
    }

    final readings = rows
        .map(PalmReading.fromJson)
        .where((reading) => reading.id.isNotEmpty)
        .toList(growable: false);
    return Future.wait(
      readings.map((reading) async {
        if (reading.imagePath.isEmpty) return reading;
        try {
          final signedUrl = await _signImage(reading.imagePath);
          return signedUrl == null || signedUrl.isEmpty
              ? reading
              : reading.copyWith(imageUrl: signedUrl);
        } catch (_) {
          return reading;
        }
      }),
    );
  }

  @override
  Future<void> deleteReading(String readingId) async {
    _requireUserWhenUsingSupabase();
    final data = await _invoke(<String, dynamic>{
      'action': 'palm_reading.delete',
      'reading_id': readingId,
    });
    if (data['success'] != true) {
      throw PalmReadingException(
        _failureMessage(data, fallback: '鑑定履歴を削除できませんでした。'),
        code: data['status']?.toString(),
      );
    }
  }

  void _validateImage(PalmReadingImage image) {
    if (!allowedMimeTypes.contains(image.mimeType)) {
      throw const PalmReadingException(
        'JPEG・PNG・WebP形式の写真を選んでください。',
        code: 'unsupportedImageType',
      );
    }
    if (image.bytes.isEmpty) {
      throw const PalmReadingException('写真が空です。', code: 'emptyImage');
    }
    if (image.bytes.length > maxImageBytes) {
      throw const PalmReadingException(
        '写真は4MB以下にしてください。',
        code: 'imageTooLarge',
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    try {
      final response = await _resolvedClient().functions.invoke(
            'ai-hub',
            body: body,
          );
      final data = _mapFrom(response.data);
      if (data.isNotEmpty) return data;
      throw const PalmReadingException(
        'AI鑑定サーバーから応答がありませんでした。',
        code: 'emptyResponse',
      );
    } on PalmReadingException {
      rethrow;
    } catch (error) {
      final raw = error.toString();
      if (RegExp(r'401|unauthorized', caseSensitive: false).hasMatch(raw)) {
        throw const PalmReadingException(
          '手相AI占いにはログインが必要です。',
          code: 'unauthorized',
        );
      }
      if (RegExp(
        r'402|usage|free.?limit',
        caseSensitive: false,
      ).hasMatch(raw)) {
        throw const PalmReadingException(
          'AIの利用上限に達しました。時間をおいて再試行してください。',
          code: 'freeLimitReached',
        );
      }
      throw const PalmReadingException(
        'AI鑑定に失敗しました。通信状況を確認して再試行してください。',
        code: 'invokeFailed',
      );
    }
  }

  Future<String?> _signImage(String imagePath) async {
    final signer = _imageSigner;
    if (signer != null) return signer(imagePath);
    return _resolvedClient()
        .storage
        .from(bucketName)
        .createSignedUrl(imagePath, 60 * 60);
  }

  void _requireUserWhenUsingSupabase() {
    if (_invoker != null) return;
    if (_resolvedClient().auth.currentUser == null) {
      throw const PalmReadingException(
        '手相AI占いにはログインが必要です。',
        code: 'unauthorized',
      );
    }
  }

  SupabaseClient _resolvedClient() => _client ?? Supabase.instance.client;

  String _failureMessage(
    Map<String, dynamic> data, {
    String fallback = '手相を鑑定できませんでした。',
  }) {
    final status = data['status']?.toString();
    final provided = <Object?>[data['message'], data['error']]
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .firstOrNull;
    return switch (status) {
      'imageNeedsRetake' => provided ?? '写真が不鮮明です。撮影ガイドに沿って撮り直してください。',
      'freeLimitReached' => 'AIの利用上限に達しました。時間をおいて再試行してください。',
      'budgetExceeded' => 'AIの予算上限に達しました。時間をおいて再試行してください。',
      'apiKeyRequired' => 'AI鑑定は現在準備中です。管理者がAI設定を完了するまでお待ちください。',
      _ => provided ?? fallback,
    };
  }

  Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }
}
