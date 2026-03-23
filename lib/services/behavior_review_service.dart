import 'package:intl/intl.dart';

import 'waste_tracking_service.dart';

enum BehaviorReviewEntryKind {
  action,
  utterance,
}

class BehaviorReviewEntry {
  const BehaviorReviewEntry({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.detail,
    required this.timestamp,
  });

  final String id;
  final BehaviorReviewEntryKind kind;
  final String source;
  final String title;
  final String detail;
  final DateTime timestamp;
}

class BehaviorReviewSummary {
  const BehaviorReviewSummary({
    required this.totalCount,
    required this.actionCount,
    required this.utteranceCount,
    required this.sourceCounts,
  });

  final int totalCount;
  final int actionCount;
  final int utteranceCount;
  final Map<String, int> sourceCounts;

  String? get topSource {
    if (sourceCounts.isEmpty) return null;
    final sorted = sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class BehaviorReviewService {
  const BehaviorReviewService._();

  static BehaviorReviewEntry? mapWealthStruggle(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final occurredAt = _parseDateTime(row['occurred_at']);
    if (id == null || id.isEmpty || occurredAt == null) {
      return null;
    }

    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final actionType = row['action_type']?.toString() ?? 'expense';
    final rawDescription = row['description']?.toString() ?? '';
    final detail = WasteTrackingService.stripWasteMarker(rawDescription);
    final wasteCategory =
        WasteTrackingService.extractWasteCategory(rawDescription);

    final title = switch (actionType) {
      'conquer' => '収入 ${_formatYen(amount)}',
      'transfer' => '振替 ${_formatYen(amount)}',
      _ when wasteCategory != null => '浪費・$wasteCategory ${_formatYen(amount)}',
      _ => '支出 ${_formatYen(amount)}',
    };

    return BehaviorReviewEntry(
      id: 'wealth_$id',
      kind: BehaviorReviewEntryKind.action,
      source: '資産管理',
      title: title,
      detail: detail,
      timestamp: occurredAt,
    );
  }

  static BehaviorReviewEntry? mapAgentMessage(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final createdAt = _parseDateTime(row['created_at']);
    if (id == null || id.isEmpty || createdAt == null) {
      return null;
    }

    final messageKind = row['message_kind']?.toString() ?? 'directive';
    final summary = (row['summary']?.toString() ?? '').trim();
    if (summary.isEmpty) {
      return null;
    }

    final title = switch (messageKind) {
      'board' => 'ボード発言',
      'status' => '状況共有',
      _ => '指示・メッセージ',
    };

    return BehaviorReviewEntry(
      id: 'message_$id',
      kind: BehaviorReviewEntryKind.utterance,
      source: 'AI組織',
      title: title,
      detail: summary,
      timestamp: createdAt,
    );
  }

  static BehaviorReviewEntry? mapNote(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final createdAt = _parseDateTime(row['created_at']);
    if (id == null || id.isEmpty || createdAt == null) {
      return null;
    }

    final title = (row['title']?.toString() ?? '').trim();
    final content = (row['content']?.toString() ?? '').trim();
    if (title.isEmpty && content.isEmpty) {
      return null;
    }

    return BehaviorReviewEntry(
      id: 'note_$id',
      kind: BehaviorReviewEntryKind.utterance,
      source: 'メモ',
      title: title.isEmpty ? '無題メモ' : title,
      detail: _compactText(content),
      timestamp: createdAt,
    );
  }

  static List<BehaviorReviewEntry> sortEntries(
    Iterable<BehaviorReviewEntry> entries,
  ) {
    final sorted = entries.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  static BehaviorReviewSummary summarize(
    Iterable<BehaviorReviewEntry> entries,
  ) {
    var actionCount = 0;
    var utteranceCount = 0;
    final sourceCounts = <String, int>{};

    for (final entry in entries) {
      if (entry.kind == BehaviorReviewEntryKind.action) {
        actionCount += 1;
      } else {
        utteranceCount += 1;
      }
      sourceCounts.update(
        entry.source,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return BehaviorReviewSummary(
      totalCount: actionCount + utteranceCount,
      actionCount: actionCount,
      utteranceCount: utteranceCount,
      sourceCounts: sourceCounts,
    );
  }

  static String buildReflectionPrompt(
    List<BehaviorReviewEntry> entries, {
    required int days,
  }) {
    final buffer = StringBuffer()
      ..writeln('あなたは厳しくも建設的な内省コーチです。')
      ..writeln('以下はユーザーの直近$days日間の行動と発言の記録です。')
      ..writeln('後悔や反省を減らすため、浅い反応・繰り返しやすい失敗・守れている価値観を考察してください。')
      ..writeln('出力は日本語で、見出しつきの短い箇条書きにしてください。')
      ..writeln('見出し:')
      ..writeln('1. 全体所見')
      ..writeln('2. 後悔につながりやすいパターン')
      ..writeln('3. 守れている価値観')
      ..writeln('4. 次に行動や発言をする前の自問3つ')
      ..writeln('5. 明日からの具体策3つ')
      ..writeln()
      ..writeln('[ログ]');

    for (final entry in entries.take(80)) {
      buffer.writeln(
        '- ${DateFormat('yyyy/MM/dd HH:mm').format(entry.timestamp)}'
        ' | ${entry.kind == BehaviorReviewEntryKind.action ? '行動' : '発言'}'
        ' | ${entry.source}'
        ' | ${entry.title}'
        '${entry.detail.isNotEmpty ? ' | ${entry.detail}' : ''}',
      );
    }

    return buffer.toString();
  }

  static String buildMyStruggleColumnPrompt(
    List<BehaviorReviewEntry> entries, {
    required int days,
    required BehaviorReviewSummary summary,
  }) {
    final buffer = StringBuffer()
      ..writeln('あなたは生活コラムニストです。')
      ..writeln('以下のログだけを根拠に、日本語で短い生活コラムを書いてください。')
      ..writeln('タイトルは必ず「我が闘争」にしてください。')
      ..writeln('ここでの「我が闘争」は、日々の暮らし・習慣・仕事・浪費・言葉遣いとの格闘を意味します。')
      ..writeln('政治思想、差別、暴力、扇動、憎悪表現は含めないでください。')
      ..writeln('精神論だけで終わらせず、ログ中の具体的な事実を最低3つ引用してください。')
      ..writeln('不明な事実は推測しないでください。')
      ..writeln('構成は次の順にしてください。')
      ..writeln('1. タイトル「我が闘争」')
      ..writeln('2. 本文 4〜6段落')
      ..writeln('3. 最後に「明日の一手:」で始まる具体策を1〜3個')
      ..writeln()
      ..writeln('[集計]')
      ..writeln('- 対象期間: 過去$days日')
      ..writeln('- 総件数: ${summary.totalCount}')
      ..writeln('- 行動件数: ${summary.actionCount}')
      ..writeln('- 発言件数: ${summary.utteranceCount}')
      ..writeln('- 最多ソース: ${summary.topSource ?? 'なし'}')
      ..writeln()
      ..writeln('[ログ]');

    for (final entry in entries.take(60)) {
      buffer.writeln(
        '- ${DateFormat('yyyy/MM/dd HH:mm').format(entry.timestamp)}'
        ' | ${entry.kind == BehaviorReviewEntryKind.action ? '行動' : '発言'}'
        ' | ${entry.source}'
        ' | ${entry.title}'
        '${entry.detail.isNotEmpty ? ' | ${entry.detail}' : ''}',
      );
    }

    return buffer.toString();
  }

  static String _compactText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 120) {
      return normalized;
    }
    return '${normalized.substring(0, 120)}...';
  }

  static DateTime? _parseDateTime(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String _formatYen(double value) {
    return '¥${NumberFormat('#,##0', 'ja_JP').format(value.round())}';
  }
}
