import 'package:flutter/foundation.dart';

/// ユーザーによる AI 出力の RLHF 評価区分 (#2659).
enum RlhfRatingStatus {
  good('good', '問題なし (Good)'),
  bad('bad', '問題あり (Bad)'),
  problematic('problematic', '要改善 (Problematic)');

  const RlhfRatingStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get triggersGitHubIssue =>
      this == RlhfRatingStatus.bad || this == RlhfRatingStatus.problematic;

  static RlhfRatingStatus fromDbValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in RlhfRatingStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return RlhfRatingStatus.bad;
  }
}

/// Database Webhook -> GitHub Issue 起票ステータス (#2659).
enum RlhfDispatchStatus {
  notNeeded('not_needed', '起票対象外'),
  pending('pending', '起票キュー待機中'),
  processing('processing', '起票処理中'),
  dispatched('dispatched', 'Issue 起票済み'),
  skipped('skipped', '重複スキップ'),
  failed('failed', '起票失敗');

  const RlhfDispatchStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static RlhfDispatchStatus fromDbValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in RlhfDispatchStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return RlhfDispatchStatus.pending;
  }
}

/// RLHF フィードバック永続レコードモデル (#2659).
@immutable
class AiRlhfFeedbackEntry {
  const AiRlhfFeedbackEntry({
    required this.id,
    required this.actionName,
    required this.modelId,
    required this.promptText,
    required this.aiOutput,
    required this.ratingStatus,
    required this.userComment,
    required this.dispatchStatus,
    this.githubIssueNumber,
    this.githubIssueUrl,
    this.webhookDispatchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiRlhfFeedbackEntry.fromSupabaseRow(Map<String, Object?> row) {
    final issueRaw = row['github_issue_number'];
    final issueNumber = issueRaw is num ? issueRaw.toInt() : null;
    final createdRaw = row['created_at']?.toString() ?? '';
    final updatedRaw = row['updated_at']?.toString() ?? '';
    final dispatchedRaw = row['webhook_dispatched_at']?.toString() ?? '';

    return AiRlhfFeedbackEntry(
      id: row['id']?.toString() ?? '',
      actionName: row['action_name']?.toString() ?? '',
      modelId: row['model_id']?.toString() ?? '',
      promptText: row['prompt_text']?.toString() ?? '',
      aiOutput: row['ai_output']?.toString() ?? '',
      ratingStatus: RlhfRatingStatus.fromDbValue(
        row['rating_status']?.toString(),
      ),
      userComment: row['user_comment']?.toString() ?? '',
      dispatchStatus: RlhfDispatchStatus.fromDbValue(
        row['dispatch_status']?.toString(),
      ),
      githubIssueNumber: issueNumber,
      githubIssueUrl: row['github_issue_url']?.toString(),
      webhookDispatchedAt: DateTime.tryParse(dispatchedRaw),
      createdAt: DateTime.tryParse(createdRaw) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(updatedRaw) ?? DateTime.now().toUtc(),
    );
  }

  final String id;
  final String actionName;
  final String modelId;
  final String promptText;
  final String aiOutput;
  final RlhfRatingStatus ratingStatus;
  final String userComment;
  final RlhfDispatchStatus dispatchStatus;
  final int? githubIssueNumber;
  final String? githubIssueUrl;
  final DateTime? webhookDispatchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiRlhfFeedbackEntry copyWith({
    String? id,
    RlhfRatingStatus? ratingStatus,
    String? userComment,
    RlhfDispatchStatus? dispatchStatus,
    int? githubIssueNumber,
    String? githubIssueUrl,
    DateTime? webhookDispatchedAt,
    DateTime? updatedAt,
  }) {
    return AiRlhfFeedbackEntry(
      id: id ?? this.id,
      actionName: actionName,
      modelId: modelId,
      promptText: promptText,
      aiOutput: aiOutput,
      ratingStatus: ratingStatus ?? this.ratingStatus,
      userComment: userComment ?? this.userComment,
      dispatchStatus: dispatchStatus ?? this.dispatchStatus,
      githubIssueNumber: githubIssueNumber ?? this.githubIssueNumber,
      githubIssueUrl: githubIssueUrl ?? this.githubIssueUrl,
      webhookDispatchedAt: webhookDispatchedAt ?? this.webhookDispatchedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 新規 RLHF フィードバック登録入力ドラフト (#2659).
@immutable
class AiRlhfFeedbackDraft {
  const AiRlhfFeedbackDraft({
    required this.actionName,
    required this.modelId,
    required this.promptText,
    required this.aiOutput,
    required this.ratingStatus,
    required this.userComment,
  });

  final String actionName;
  final String modelId;
  final String promptText;
  final String aiOutput;
  final RlhfRatingStatus ratingStatus;
  final String userComment;
}

/// Webhook ディスパッチ実行結果 (#2659).
@immutable
class RlhfWebhookDispatchResult {
  const RlhfWebhookDispatchResult({
    required this.feedbackId,
    required this.dispatched,
    this.skipped = false,
    this.dryRun = false,
    this.issueNumber,
    this.issueUrl,
    this.labels = const <String>[],
    this.message = '',
  });

  final String feedbackId;
  final bool dispatched;
  final bool skipped;
  final bool dryRun;
  final int? issueNumber;
  final String? issueUrl;
  final List<String> labels;
  final String message;
}

/// RLHF Bad Feedback データ層インターフェース (#2659).
abstract interface class AiRlhfFeedbackRepository {
  Future<List<AiRlhfFeedbackEntry>> fetchRecentFeedback();

  Future<AiRlhfFeedbackEntry> submitFeedback(AiRlhfFeedbackDraft draft);

  Future<RlhfWebhookDispatchResult> triggerWebhookDispatch({
    required String feedbackId,
    bool dryRun = false,
  });
}
