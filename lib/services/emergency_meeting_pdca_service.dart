import 'dart:convert';

import 'package:my_web_app/models/board_meeting.dart';

class EmergencyMeetingPdcaMetrics {
  final int continuationCompletedCount;
  final int continuationTotalCount;
  final int continuationCompletionRatePercent;
  final int continuationQuickStartCount;
  final int continuationTimeBlockReservedCount;
  final int continuationProgressLogCount;
  final int abstinenceViolationCount;
  final int abstinenceNoViolationDays;
  final int abstinenceRuleCompletedCount;
  final int abstinenceRuleTotalCount;
  final int abstinenceRuleCompletionRatePercent;
  final int abstinenceRecoveredWithin10mCount;
  final int abstinenceRecoveryWindowMissedCount;
  final int deepWorkSessionCount;
  final int weeklyPriorityReviewCount;
  final int accountabilityShareCount;
  final int abstinenceRecoveryActionCount;
  final bool reminderEnabled;
  final int deterrenceLockEnabledCount;
  final int deterrenceStrictModeBlockCount;
  final int deterrenceLockCoveragePercent;
  final DateTime? abstinenceRecoveryDueAt;
  final List<String> activeDeterrenceLocks;
  final DateTime? lastReviewAt;

  const EmergencyMeetingPdcaMetrics({
    required this.continuationCompletedCount,
    required this.continuationTotalCount,
    required this.continuationCompletionRatePercent,
    this.continuationQuickStartCount = 0,
    this.continuationTimeBlockReservedCount = 0,
    this.continuationProgressLogCount = 0,
    required this.abstinenceViolationCount,
    required this.abstinenceNoViolationDays,
    this.abstinenceRuleCompletedCount = 0,
    this.abstinenceRuleTotalCount = 0,
    this.abstinenceRuleCompletionRatePercent = 0,
    this.abstinenceRecoveredWithin10mCount = 0,
    this.abstinenceRecoveryWindowMissedCount = 0,
    this.deepWorkSessionCount = 0,
    this.weeklyPriorityReviewCount = 0,
    this.accountabilityShareCount = 0,
    this.abstinenceRecoveryActionCount = 0,
    required this.reminderEnabled,
    this.deterrenceLockEnabledCount = 0,
    this.deterrenceStrictModeBlockCount = 0,
    this.deterrenceLockCoveragePercent = 0,
    this.abstinenceRecoveryDueAt,
    required this.activeDeterrenceLocks,
    this.lastReviewAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'continuation_completed_count': continuationCompletedCount,
      'continuation_total_count': continuationTotalCount,
      'continuation_completion_rate_percent': continuationCompletionRatePercent,
      'continuation_quick_start_count': continuationQuickStartCount,
      'continuation_time_block_reserved_count':
          continuationTimeBlockReservedCount,
      'continuation_progress_log_count': continuationProgressLogCount,
      'abstinence_violation_count': abstinenceViolationCount,
      'abstinence_no_violation_days': abstinenceNoViolationDays,
      'abstinence_rule_completed_count': abstinenceRuleCompletedCount,
      'abstinence_rule_total_count': abstinenceRuleTotalCount,
      'abstinence_rule_completion_rate_percent':
          abstinenceRuleCompletionRatePercent,
      'abstinence_recovered_within_10m_count':
          abstinenceRecoveredWithin10mCount,
      'abstinence_recovery_window_missed_count':
          abstinenceRecoveryWindowMissedCount,
      'deep_work_session_count': deepWorkSessionCount,
      'weekly_priority_review_count': weeklyPriorityReviewCount,
      'accountability_share_count': accountabilityShareCount,
      'abstinence_recovery_action_count': abstinenceRecoveryActionCount,
      'reminder_enabled': reminderEnabled,
      'deterrence_lock_enabled_count': deterrenceLockEnabledCount,
      'deterrence_strict_mode_block_count': deterrenceStrictModeBlockCount,
      'deterrence_lock_coverage_percent': deterrenceLockCoveragePercent,
      'abstinence_recovery_due_at': abstinenceRecoveryDueAt?.toIso8601String(),
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
