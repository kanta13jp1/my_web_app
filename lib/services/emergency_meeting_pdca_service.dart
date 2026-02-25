import 'dart:convert';

import 'package:my_web_app/models/board_meeting.dart';

class EmergencyMeetingPdcaMetrics {
  final int continuationCompletedCount;
  final int continuationTotalCount;
  final int continuationCompletionRatePercent;
  final int abstinenceViolationCount;
  final int abstinenceNoViolationDays;
  final bool reminderEnabled;
  final List<String> activeDeterrenceLocks;
  final DateTime? lastReviewAt;

  const EmergencyMeetingPdcaMetrics({
    required this.continuationCompletedCount,
    required this.continuationTotalCount,
    required this.continuationCompletionRatePercent,
    required this.abstinenceViolationCount,
    required this.abstinenceNoViolationDays,
    required this.reminderEnabled,
    required this.activeDeterrenceLocks,
    this.lastReviewAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'continuation_completed_count': continuationCompletedCount,
      'continuation_total_count': continuationTotalCount,
      'continuation_completion_rate_percent': continuationCompletionRatePercent,
      'abstinence_violation_count': abstinenceViolationCount,
      'abstinence_no_violation_days': abstinenceNoViolationDays,
      'reminder_enabled': reminderEnabled,
      'active_deterrence_locks': activeDeterrenceLocks,
      'last_review_at': lastReviewAt?.toIso8601String(),
    };
  }
}

class EmergencyMeetingCodexFormatter {
  static String formatForCodex({
    required BoardMeetingLog log,
    required String focusLabel,
    required String model,
    required List<String> continuationPlan,
    required List<String> abstinenceRules,
    required String? riskAlert,
    required EmergencyMeetingPdcaMetrics metrics,
  }) {
    final payload = <String, dynamic>{
      'meeting_id': log.id,
      'created_at': log.createdAt.toIso8601String(),
      'topic': log.topic,
      'focus': focusLabel,
      'model': model,
      'messages': log.messages
          .map(
            (msg) => <String, dynamic>{
              'role': msg.role,
              'speaker_name': msg.speakerName,
              'content': msg.content,
            },
          )
          .toList(),
      'continuation_plan': continuationPlan,
      'abstinence_rules': abstinenceRules,
      'risk_alert': riskAlert,
      'conclusion': log.conclusion,
      'next_meeting_metrics': metrics.toJson(),
    };
    final jsonPayload = const JsonEncoder.withIndent('  ').convert(payload);

    return '''
【緊急役員会議 → Codex 連携データ】
この内容をもとに、次のPDCA改善（実装 + テスト）を提案・実装してください。

1. 継続アクションが実行しやすくなるUI/導線改善
2. 禁欲ルールの実行率を上げる抑止設計（通知・制限・可視化）
3. 次回会議で検証できる計測項目の追加

--- Meeting Result JSON ---
$jsonPayload
''';
  }
}
