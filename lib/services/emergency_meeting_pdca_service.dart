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

class EmergencyMeetingReportContext {
  final String userId;
  final int noteCount;
  final int subscriptionCount;
  final int points;
  final int level;
  final int currentStreak;
  final int danshariCount;
  final String focusLabel;
  final String focusInstruction;
  final EmergencyMeetingPdcaMetrics metrics;
  final String? startupContext;

  const EmergencyMeetingReportContext({
    required this.userId,
    required this.noteCount,
    required this.subscriptionCount,
    required this.points,
    required this.level,
    required this.currentStreak,
    required this.danshariCount,
    required this.focusLabel,
    required this.focusInstruction,
    required this.metrics,
    this.startupContext,
  });
}

class EmergencyMeetingAiReport {
  final List<BoardMessage> messages;
  final String conclusion;
  final List<String> continuationPlan;
  final List<String> abstinenceRules;
  final String riskAlert;
  final Map<String, dynamic> nextMeetingMetrics;
  final String? decodeNotice;

  const EmergencyMeetingAiReport({
    required this.messages,
    required this.conclusion,
    required this.continuationPlan,
    required this.abstinenceRules,
    required this.riskAlert,
    required this.nextMeetingMetrics,
    this.decodeNotice,
  });
}

class EmergencyMeetingBiReportService {
  static const List<String> _requiredRoles = <String>[
    'CFO',
    'CKO',
    'CHRO',
    'CEO',
  ];

  String buildPrompt(EmergencyMeetingReportContext context) {
    final buffer = StringBuffer()
      ..writeln('あなたは「自分株式会社」の緊急役員会議 BI レポート生成システムです。')
      ..writeln('雑談ではなく、数字を根拠に短く具体的な経営会議レポートを返してください。')
      ..writeln()
      ..writeln('[会議フォーカス]')
      ..writeln('- label: ${context.focusLabel}')
      ..writeln('- instruction: ${context.focusInstruction}')
      ..writeln()
      ..writeln('[現状データ]')
      ..writeln('- user_id: ${context.userId}')
      ..writeln('- notes: ${context.noteCount}')
      ..writeln('- subscriptions: ${context.subscriptionCount}')
      ..writeln('- total_points: ${context.points}')
      ..writeln('- current_level: ${context.level}')
      ..writeln('- current_streak: ${context.currentStreak}')
      ..writeln('- danshari_items: ${context.danshariCount}')
      ..writeln()
      ..writeln('[PDCA metrics JSON]')
      ..writeln(
          const JsonEncoder.withIndent('  ').convert(context.metrics.toJson()))
      ..writeln()
      ..writeln('[発言ルール]')
      ..writeln('- CFO: サブスク、ポイント、固定費、投資対効果を報告する。')
      ..writeln('- CKO: ノート量、継続実行、深い作業、知識の実行率を報告する。')
      ..writeln('- CHRO: ストリーク、禁欲、回復行動、習慣の崩れやすさを報告する。')
      ..writeln('- CEO: 3名の報告を統合し、48時間以内の実行判断を下す。')
      ..writeln('- 数字がある項目は具体的に引用し、不明な数字は推測しない。')
      ..writeln('- 各発言は「現状の数字 -> 問題解釈 -> 次の一手」の順で 2〜4 文にする。')
      ..writeln('- 精神論や抽象論だけで終わらせない。')
      ..writeln()
      ..writeln('[出力制約]')
      ..writeln('- JSON 以外を返さない。')
      ..writeln('- messages は CFO, CKO, CHRO, CEO の順で 4 件。')
      ..writeln('- conclusion は CEO が今すぐ実行すべき具体策を 1 段落でまとめる。');

    final startupContext = context.startupContext?.trim();
    if (startupContext != null && startupContext.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[役員の追加コンテキスト]')
        ..writeln(startupContext);
    }

    return buffer.toString().trim();
  }

  EmergencyMeetingAiReport normalizeReport({
    required Map<String, dynamic> rawResult,
    required EmergencyMeetingReportContext context,
    DateTime? generatedAt,
  }) {
    final timestamp = generatedAt ?? DateTime.now();
    final extractedMessages = _extractMessages(
      rawResult['messages'],
      timestamp: timestamp,
    );
    final continuationPlan = _extractStringList(rawResult['continuation_plan']);
    final abstinenceRules = _extractStringList(rawResult['abstinence_rules']);
    final rawConclusion = _readString(rawResult['conclusion']);
    final rawRiskAlert = _readString(rawResult['risk_alert']);
    final rawMetrics = _extractMap(rawResult['next_meeting_metrics']);

    final normalizedContinuationPlan = continuationPlan.isNotEmpty
        ? _limitToThree(continuationPlan)
        : buildContinuationPlan(context);
    final normalizedAbstinenceRules = abstinenceRules.isNotEmpty
        ? _limitToThree(abstinenceRules)
        : buildAbstinenceRules(context);
    final normalizedRiskAlert = rawRiskAlert ?? buildRiskAlert(context);
    final normalizedConclusion =
        (rawConclusion != null && rawConclusion.isNotEmpty)
            ? rawConclusion
            : buildConclusion(
                context: context,
                continuationPlan: normalizedContinuationPlan,
                abstinenceRules: normalizedAbstinenceRules,
                riskAlert: normalizedRiskAlert,
              );

    final fallbackMessages = _buildFallbackMessages(
      context: context,
      timestamp: timestamp,
      riskAlert: normalizedRiskAlert,
      continuationPlan: normalizedContinuationPlan,
    );
    final mergedMessages = _mergeWithFallbackMessages(
      extractedMessages: extractedMessages,
      fallbackMessages: fallbackMessages,
    );

    final nextMeetingMetrics = <String, dynamic>{
      ...context.metrics.toJson(),
      if (rawMetrics != null) ...rawMetrics,
    };

    final usedFallback = extractedMessages.length < _requiredRoles.length ||
        rawConclusion == null ||
        rawConclusion.isEmpty;

    return EmergencyMeetingAiReport(
      messages: mergedMessages,
      conclusion: normalizedConclusion,
      continuationPlan: normalizedContinuationPlan,
      abstinenceRules: normalizedAbstinenceRules,
      riskAlert: normalizedRiskAlert,
      nextMeetingMetrics: nextMeetingMetrics,
      decodeNotice: usedFallback ? 'AI出力が不完全だったため、BI テンプレートで安全に補完しました。' : null,
    );
  }

  List<String> buildContinuationPlan(EmergencyMeetingReportContext context) {
    final metrics = context.metrics;
    final actions = <String>[];

    switch (context.focusLabel) {
      case '継続実行を最優先':
        actions.add('次の48時間で最重要案件を1件だけ選び、開始時刻付きで着手する。');
        break;
      case '禁欲と回復を最優先':
        actions.add('最も危険な誘惑トリガーを1つ遮断し、その直後に代替行動を予約する。');
        break;
      default:
        actions.add('今日中に最重要タスクを1件だけ決め、25分で初手まで進める。');
        break;
    }

    if (metrics.continuationTimeBlockReservedCount <= 0) {
      actions.add('次の48時間のカレンダーに、継続案件の固定ブロックを最低1枠入れる。');
    } else {
      actions.add('確保済みの時間ブロックで進捗ログを1回残し、着手だけで終わらせない。');
    }

    if (metrics.accountabilityShareCount <= 0) {
      actions.add('会議の結論を1人に共有し、完了条件と期限を先に宣言する。');
    } else {
      actions.add('共有済みの相手に48時間以内の進捗を再報告し、次の障害を潰す。');
    }

    return _dedupeAndTakeThree(actions);
  }

  List<String> buildAbstinenceRules(EmergencyMeetingReportContext context) {
    final metrics = context.metrics;
    final rules = <String>[];

    if (metrics.activeDeterrenceLocks.isEmpty) {
      rules.add('最も危険なトリガーに対して、今日中に1つロックを有効化する。');
    } else {
      rules.add(
          '有効化したロック（${metrics.activeDeterrenceLocks.join(' / ')}）を自分判断で解除しない。');
    }

    if (metrics.abstinenceRecoveryWindowMissedCount > 0) {
      rules.add('誘惑が出たら10分以内に回復行動を実行し、未実施のまま放置しない。');
    } else {
      rules.add('誘惑の兆候を感じた時点で席を立ち、5分以内に環境を切り替える。');
    }

    if (!metrics.reminderEnabled) {
      rules.add('今日中にリマインダーを有効化し、夜の油断時間に自動で警告を出す。');
    } else {
      rules.add('夜に意思決定しない。迷った案件は翌朝レビューへ送る。');
    }

    return _dedupeAndTakeThree(rules);
  }

  String buildRiskAlert(EmergencyMeetingReportContext context) {
    final metrics = context.metrics;
    if (metrics.abstinenceViolationCount > 0 &&
        metrics.abstinenceRecoveryWindowMissedCount > 0) {
      return '誘惑の再発と回復遅れが同時に起きており、感情で計画が崩れるリスクが高いです。';
    }
    if (metrics.continuationCompletionRatePercent < 50 &&
        metrics.continuationTimeBlockReservedCount <= 0) {
      return '重要案件が着手前で止まっており、今週も先送りが固定化するリスクが高いです。';
    }
    if (metrics.deterrenceLockCoveragePercent < 50) {
      return '誘惑対策のロックが薄く、例外を一度許すと習慣が逆戻りするリスクがあります。';
    }
    if (context.subscriptionCount >= 5) {
      return '固定費の見直しが遅れると、改善余地より先に維持コストが膨らむ可能性があります。';
    }
    return '判断だけ増えて実行が伴わないと、会議の熱量がそのまま失速するリスクがあります。';
  }

  String buildConclusion({
    required EmergencyMeetingReportContext context,
    required List<String> continuationPlan,
    required List<String> abstinenceRules,
    required String riskAlert,
  }) {
    final firstAction =
        continuationPlan.isNotEmpty ? continuationPlan.first : '最重要案件を1件着手する';
    final firstRule =
        abstinenceRules.isNotEmpty ? abstinenceRules.first : '危険なトリガーを1つ遮断する';
    return 'フォーカスは「${context.focusLabel}」です。まずは $firstAction 同時に $firstRule を徹底してください。$riskAlert';
  }

  List<BoardMessage> _extractMessages(
    dynamic rawMessages, {
    required DateTime timestamp,
  }) {
    if (rawMessages is! List) {
      return const <BoardMessage>[];
    }

    final messages = <BoardMessage>[];
    for (var i = 0; i < rawMessages.length; i++) {
      final item = rawMessages[i];
      if (item is! Map) continue;
      final message = Map<String, dynamic>.from(item);
      final role = _normalizeRole(_readString(message['role']));
      final content = _readString(message['content']);
      if (content == null || content.isEmpty) continue;
      final speakerName = _readString(message['speaker_name']) ??
          _readString(message['speakerName']) ??
          'AI $role';
      messages.add(
        BoardMessage(
          id: 'meeting-message-$i',
          speakerName: speakerName,
          role: role,
          content: content,
          timestamp: timestamp,
        ),
      );
    }
    return messages;
  }

  List<BoardMessage> _mergeWithFallbackMessages({
    required List<BoardMessage> extractedMessages,
    required List<BoardMessage> fallbackMessages,
  }) {
    final byRole = <String, BoardMessage>{};
    for (final message in extractedMessages) {
      byRole[message.role] = message;
    }

    final ordered = <BoardMessage>[];
    for (final fallback in fallbackMessages) {
      ordered.add(byRole[fallback.role] ?? fallback);
    }

    for (final message in extractedMessages) {
      if (!_requiredRoles.contains(message.role)) {
        ordered.add(message);
      }
    }
    return ordered;
  }

  List<BoardMessage> _buildFallbackMessages({
    required EmergencyMeetingReportContext context,
    required DateTime timestamp,
    required String riskAlert,
    required List<String> continuationPlan,
  }) {
    final metrics = context.metrics;
    final firstAction =
        continuationPlan.isNotEmpty ? continuationPlan.first : '最重要案件を1件着手する';

    return <BoardMessage>[
      BoardMessage(
        id: 'fallback-cfo',
        speakerName: 'AI CFO',
        role: 'CFO',
        content:
            'サブスクは ${context.subscriptionCount} 件、ポイントは ${context.points} です。固定費と期待成果の見直しを止めると、改善余地がコストに食われます。まずは不要な維持コスト候補を1件洗い出してください。',
        timestamp: timestamp,
      ),
      BoardMessage(
        id: 'fallback-cko',
        speakerName: 'AI CKO',
        role: 'CKO',
        content:
            'ノートは ${context.noteCount} 件、継続完了率は ${metrics.continuationCompletionRatePercent}% です。知識は十分でも実行ブロックが弱いと成果に変わりません。最初の一手は「$firstAction」です。',
        timestamp: timestamp,
      ),
      BoardMessage(
        id: 'fallback-chro',
        speakerName: 'AI CHRO',
        role: 'CHRO',
        content:
            '現在ストリークは ${context.currentStreak} 日、禁欲違反は ${metrics.abstinenceViolationCount} 件です。習慣の守りが弱い日は判断も崩れやすくなります。回復行動とロック運用を例外なく回してください。',
        timestamp: timestamp,
      ),
      BoardMessage(
        id: 'fallback-ceo',
        speakerName: 'AI CEO',
        role: 'CEO',
        content:
            '今回のフォーカスは ${context.focusLabel} です。役員会議の結論は、行動を絞って48時間以内に着手し、守りを先に固めることです。最大リスクは「$riskAlert」です。',
        timestamp: timestamp,
      ),
    ];
  }

  List<String> _extractStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _extractMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String _normalizeRole(String? role) {
    final normalized = role?.trim().toUpperCase();
    switch (normalized) {
      case 'CMO':
      case 'CSO':
        return 'CKO';
      case 'CHO':
        return 'CHRO';
      case 'CFO':
      case 'CKO':
      case 'CHRO':
      case 'CEO':
        return normalized!;
      default:
        return 'CEO';
    }
  }

  List<String> _limitToThree(List<String> items) {
    return _dedupeAndTakeThree(items);
  }

  List<String> _dedupeAndTakeThree(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final normalized = item.trim();
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      result.add(normalized);
      if (result.length == 3) {
        break;
      }
    }
    return result;
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
