import 'package:flutter/foundation.dart';

/// バックグラウンド要約ジョブの実行ステータス。
enum LongFormSummaryStatus {
  queued('queued', '要約待機中'),
  processing('processing', '要約生成中'),
  completed('completed', '要約完了'),
  rateLimited('rate_limited', 'レート制限'),
  failed('failed', '生成失敗');

  const LongFormSummaryStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static LongFormSummaryStatus fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final LongFormSummaryStatus status in LongFormSummaryStatus.values) {
      if (status.dbValue == normalized) {
        return status;
      }
    }
    return LongFormSummaryStatus.queued;
  }
}

/// 長文ドキュメントと自動生成された要約レコードの結合モデル。
@immutable
class LongFormDocumentWithSummary {
  const LongFormDocumentWithSummary({
    required this.documentId,
    required this.title,
    required this.bodyText,
    required this.charCount,
    required this.summaryText,
    required this.status,
    this.retryAfterSeconds = 0,
    this.modelName = 'extractive-local-v1',
    this.createdAtIso = '',
  });

  final String documentId;
  final String title;
  final String bodyText;
  final int charCount;
  final String summaryText;
  final LongFormSummaryStatus status;
  final int retryAfterSeconds;
  final String modelName;
  final String createdAtIso;

  bool get hasReadySummary =>
      summaryText.trim().isNotEmpty &&
      status == LongFormSummaryStatus.completed;

  LongFormDocumentWithSummary copyWith({
    String? summaryText,
    LongFormSummaryStatus? status,
    int? retryAfterSeconds,
    String? modelName,
  }) {
    return LongFormDocumentWithSummary(
      documentId: documentId,
      title: title,
      bodyText: bodyText,
      charCount: charCount,
      summaryText: summaryText ?? this.summaryText,
      status: status ?? this.status,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
      modelName: modelName ?? this.modelName,
      createdAtIso: createdAtIso,
    );
  }

  factory LongFormDocumentWithSummary.fromDocumentAndSummaryJson({
    required Map<String, Object?> docJson,
    Map<String, Object?>? summaryJson,
  }) {
    final String body = (docJson['body_text'] as String? ?? '').trim();
    return LongFormDocumentWithSummary(
      documentId: (docJson['id'] as String? ?? '').trim(),
      title: (docJson['title'] as String? ?? '').trim(),
      bodyText: body,
      charCount: (docJson['char_count'] as num?)?.toInt() ?? body.length,
      summaryText: (summaryJson?['summary_text'] as String? ?? '').trim(),
      status: LongFormSummaryStatus.fromDb(
        summaryJson?['status'] as String?,
      ),
      retryAfterSeconds:
          (summaryJson?['retry_after_seconds'] as num?)?.toInt() ?? 0,
      modelName:
          (summaryJson?['model_name'] as String? ?? 'extractive-local-v1')
              .trim(),
      createdAtIso: (docJson['created_at'] as String? ?? '').trim(),
    );
  }
}

/// 決定論的な入力検証およびオフライン即時要約プレビュービルダー。
class LongFormSummaryBuilder {
  const LongFormSummaryBuilder._();

  static const int minTitleLength = 1;
  static const int maxTitleLength = 200;
  static const int minAutoSummaryChars = 400;

  static String? validateDocument({
    required String title,
    required String bodyText,
  }) {
    final String trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > maxTitleLength) {
      return 'タイトルは $minTitleLength〜$maxTitleLength 文字で入力してください。';
    }
    if (bodyText.trim().isEmpty) {
      return '本文テキストを入力してください。';
    }
    return null;
  }

  static String buildLocalPreviewSummary(String bodyText) {
    final String normalized = bodyText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return '';
    }
    final List<String> segments = normalized
        .split(RegExp(r'(?<=[。！？.!?])\s*'))
        .where((String s) => s.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return normalized.length <= 180
          ? normalized
          : '${normalized.substring(0, 179)}…';
    }
    final StringBuffer buffer = StringBuffer();
    for (final String seg in segments.take(2)) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(seg);
      if (buffer.length >= 180) {
        break;
      }
    }
    final String result = buffer.toString();
    return result.length <= 220 ? result : '${result.substring(0, 219)}…';
  }
}
