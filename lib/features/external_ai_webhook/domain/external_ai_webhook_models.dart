import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// 外部 AI / 自動化ツール連携元 (#2663).
enum ExternalWebhookSourceTool {
  n8n('n8n', 'n8n'),
  zapier('zapier', 'Zapier'),
  analytics('analytics', 'Analytics'),
  custom('custom', 'Custom');

  const ExternalWebhookSourceTool(this.wireValue, this.displayLabel);

  final String wireValue;
  final String displayLabel;

  static ExternalWebhookSourceTool fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in ExternalWebhookSourceTool.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return ExternalWebhookSourceTool.custom;
  }
}

/// Webhook イベントの処理ステータス (#2663).
enum ExternalWebhookProcessingStatus {
  received('received', '受信済み'),
  processed('processed', '処理完了'),
  failed('failed', '失敗');

  const ExternalWebhookProcessingStatus(this.wireValue, this.displayLabel);

  final String wireValue;
  final String displayLabel;

  static ExternalWebhookProcessingStatus fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in ExternalWebhookProcessingStatus.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return ExternalWebhookProcessingStatus.received;
  }
}

/// Webhook 認証方式 (#2663).
enum ExternalWebhookAuthMethod {
  apiKey('api_key', 'APIキー'),
  jwt('jwt', 'JWT');

  const ExternalWebhookAuthMethod(this.wireValue, this.displayLabel);

  final String wireValue;
  final String displayLabel;

  static ExternalWebhookAuthMethod fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in ExternalWebhookAuthMethod.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return ExternalWebhookAuthMethod.jwt;
  }
}

/// 生成直後のみ一度だけ返却される平文 API キーと DB 保存用 SHA-256 ハッシュ (#2663).
@immutable
class GeneratedWebhookKeyMaterial {
  const GeneratedWebhookKeyMaterial({
    required this.plaintextKey,
    required this.keyPrefix,
    required this.keyHash,
  });

  final String plaintextKey;
  final String keyPrefix;
  final String keyHash;

  static GeneratedWebhookKeyMaterial generate() {
    final random = Random.secure();
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer('eaw_');
    for (var i = 0; i < 32; i += 1) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }
    final raw = buffer.toString();
    final digest = sha256.convert(utf8.encode(raw)).toString();
    return GeneratedWebhookKeyMaterial(
      plaintextKey: raw,
      keyPrefix: raw.substring(0, 12),
      keyHash: digest,
    );
  }
}

/// 外部 AI Webhook イベントレコード (#2663).
@immutable
class ExternalAiWebhookEvent {
  const ExternalAiWebhookEvent({
    required this.id,
    required this.userId,
    required this.sourceTool,
    required this.eventType,
    required this.externalEventId,
    required this.payloadSummary,
    required this.authMethod,
    required this.processingStatus,
    required this.errorMessage,
    required this.createdAt,
  });

  factory ExternalAiWebhookEvent.fromMap(final Map<String, Object?> map) {
    final rawPayload = map['payload'];
    var summary = '{}';
    if (rawPayload is Map<Object?, Object?>) {
      final safeMap = <String, Object?>{};
      for (final entry in rawPayload.entries) {
        if (entry.key != null) {
          safeMap[entry.key.toString()] = entry.value;
        }
      }
      summary = jsonEncode(safeMap);
    } else if (rawPayload != null) {
      summary = rawPayload.toString();
    }

    return ExternalAiWebhookEvent(
      id: (map['id'] as String? ?? '').trim(),
      userId: (map['user_id'] as String? ?? '').trim(),
      sourceTool:
          ExternalWebhookSourceTool.fromWire(map['source_tool'] as String?),
      eventType: (map['event_type'] as String? ?? '').trim(),
      externalEventId: (map['external_event_id'] as String? ?? '').trim(),
      payloadSummary: summary,
      authMethod:
          ExternalWebhookAuthMethod.fromWire(map['auth_method'] as String?),
      processingStatus: ExternalWebhookProcessingStatus.fromWire(
        map['processing_status'] as String?,
      ),
      errorMessage: (map['error_message'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String userId;
  final ExternalWebhookSourceTool sourceTool;
  final String eventType;
  final String externalEventId;
  final String payloadSummary;
  final ExternalWebhookAuthMethod authMethod;
  final ExternalWebhookProcessingStatus processingStatus;
  final String errorMessage;
  final DateTime createdAt;
}

/// 外部 AI Webhook API キーメタデータ（平文キーは保持しない） (#2663).
@immutable
class ExternalAiWebhookKey {
  const ExternalAiWebhookKey({
    required this.id,
    required this.userId,
    required this.label,
    required this.keyPrefix,
    required this.isActive,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory ExternalAiWebhookKey.fromMap(final Map<String, Object?> map) {
    return ExternalAiWebhookKey(
      id: (map['id'] as String? ?? '').trim(),
      userId: (map['user_id'] as String? ?? '').trim(),
      label: (map['label'] as String? ?? '').trim(),
      keyPrefix: (map['key_prefix'] as String? ?? '').trim(),
      isActive: map['is_active'] as bool? ?? false,
      lastUsedAt: DateTime.tryParse(map['last_used_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String userId;
  final String label;
  final String keyPrefix;
  final bool isActive;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  ExternalAiWebhookKey copyWith({
    final bool? isActive,
  }) {
    return ExternalAiWebhookKey(
      id: id,
      userId: userId,
      label: label,
      keyPrefix: keyPrefix,
      isActive: isActive ?? this.isActive,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }
}

/// Webhook テスト送信レスポンス (#2663).
@immutable
class ExternalWebhookInvokeResult {
  const ExternalWebhookInvokeResult({
    required this.ok,
    required this.dryRun,
    required this.authMethod,
    this.eventId,
  });

  final bool ok;
  final bool dryRun;
  final ExternalWebhookAuthMethod authMethod;
  final String? eventId;
}

/// 外部 AI Webhook リポジトリ契約 (#2663).
abstract class ExternalAiWebhookRepository {
  Future<List<ExternalAiWebhookEvent>> fetchRecentEvents({
    final int limit = 40,
  });

  Future<List<ExternalAiWebhookKey>> fetchWebhookKeys();

  Future<ExternalAiWebhookKey> createWebhookKey({
    required final String label,
    required final String keyPrefix,
    required final String keyHash,
  });

  Future<void> revokeWebhookKey(final String keyId);

  Future<ExternalWebhookInvokeResult> invokeWebhookEndpoint({
    required final ExternalWebhookSourceTool sourceTool,
    required final String eventType,
    required final Map<String, Object?> payload,
    required final bool dryRun,
  });

  bool subscribeToEvents(final void Function() onRealtimeChange);

  Future<void> disposeSubscription();
}
