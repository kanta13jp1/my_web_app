import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// 重複排除結果のメトリクス・トークン削減ログ (#2697)。
class AiDeduplicationLogEntry {
  final int totalInputs;
  final int keptCount;
  final int removedCount;
  final int rawBytesSaved;
  final int estimatedTokensSaved;
  final double threshold;
  final DateTime recordedAt;

  const AiDeduplicationLogEntry({
    required this.totalInputs,
    required this.keptCount,
    required this.removedCount,
    required this.rawBytesSaved,
    required this.estimatedTokensSaved,
    required this.threshold,
    required this.recordedAt,
  });
}

/// 入力重複排除の実行結果 (#2697)。
class AiDeduplicationResult {
  final List<String> keptInputs;
  final List<int> removedIndices;
  final AiDeduplicationLogEntry logEntry;

  const AiDeduplicationResult({
    required this.keptInputs,
    required this.removedIndices,
    required this.logEntry,
  });
}

/// GZip 圧縮距離 (NCD) を用いて AI 入力テキストの重複を排除するサービス (#2697)。
class AiInputDeduplicationService {
  final GZipEncoder _encoder;
  final List<AiDeduplicationLogEntry> _logs = <AiDeduplicationLogEntry>[];

  AiInputDeduplicationService({GZipEncoder? encoder})
      : _encoder = encoder ?? const GZipEncoder();

  List<AiDeduplicationLogEntry> get logs =>
      List<AiDeduplicationLogEntry>.unmodifiable(_logs);

  /// UTF-8 バイト列を GZip 圧縮した際のバイトサイズを返す。
  int compressedSize(String text) {
    final raw = utf8.encode(text);
    final compressed = _encoder.encodeBytes(raw);
    return compressed.length;
  }

  /// Normalized Compression Distance (0.0: 同一 〜 1.0: 非類似) を算出する。
  double computeNormalizedCompressionDistance(String a, String b) {
    if (a == b) {
      return 0.0;
    }
    if (a.isEmpty || b.isEmpty) {
      return 1.0;
    }
    final ca = compressedSize(a);
    final cb = compressedSize(b);
    final cab = compressedSize('$a\n$b');
    final minC = math.min(ca, cb);
    final maxC = math.max(ca, cb);
    if (maxC <= 0) {
      return 0.0;
    }
    return ((cab - minC) / maxC).clamp(0.0, 1.0);
  }

  /// 圧縮距離ベースの類似度 (0.0: 非類似 〜 1.0: 同一) を返す。
  double computeCompressionSimilarity(String a, String b) =>
      (1.0 - computeNormalizedCompressionDistance(a, b)).clamp(0.0, 1.0);

  /// 閾値以上の類似度を持つ重複入力を除外し、削減ログを記録する。
  AiDeduplicationResult deduplicateInputs(
    List<String> inputs, {
    double similarityThreshold = 0.72,
    DateTime? now,
    void Function(AiDeduplicationLogEntry entry)? onLog,
  }) {
    final kept = <String>[];
    final removedIndices = <int>[];
    var rawBytesSaved = 0;

    for (var i = 0; i < inputs.length; i++) {
      final candidate = inputs[i];
      var duplicate = false;
      for (final existing in kept) {
        if (candidate.trim() == existing.trim() ||
            computeCompressionSimilarity(existing, candidate) >=
                similarityThreshold) {
          duplicate = true;
          break;
        }
      }
      if (duplicate) {
        removedIndices.add(i);
        rawBytesSaved += utf8.encode(candidate).length;
      } else {
        kept.add(candidate);
      }
    }

    final estimatedTokensSaved =
        rawBytesSaved <= 0 ? 0 : math.max(1, (rawBytesSaved / 4).ceil());
    final entry = AiDeduplicationLogEntry(
      totalInputs: inputs.length,
      keptCount: kept.length,
      removedCount: removedIndices.length,
      rawBytesSaved: rawBytesSaved,
      estimatedTokensSaved: estimatedTokensSaved,
      threshold: similarityThreshold,
      recordedAt: (now ?? DateTime.now()).toUtc(),
    );
    _logs.add(entry);
    debugPrint(
      '[AI-DEDUP] total=${entry.totalInputs} kept=${entry.keptCount} '
      'removed=${entry.removedCount} est_saved=${entry.estimatedTokensSaved}',
    );
    onLog?.call(entry);

    return AiDeduplicationResult(
      keptInputs: List<String>.unmodifiable(kept),
      removedIndices: List<int>.unmodifiable(removedIndices),
      logEntry: entry,
    );
  }
}
