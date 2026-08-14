import 'package:flutter/material.dart';

/// AI エージェント カンバンボードの表示モデルと純粋変換ロジック。
///
/// `wbs_tasks` の行を「4 列カンバン + エージェント一覧」の表示状態へ変換する。
/// ここはネットワーク・時刻に依存しない (now は引数で受け取る) ため、単体
/// テストで決定的に検証できる。

/// カンバンの列 (= wbs_tasks.status をそのまま採用。読み替えはしない)。
enum BoardLane { notStarted, inProgress, blocked, completed }

extension BoardLaneLabel on BoardLane {
  String get label => switch (this) {
        BoardLane.notStarted => '未着手',
        BoardLane.inProgress => '進行中',
        BoardLane.blocked => 'ブロック',
        BoardLane.completed => '完了',
      };

  /// DB の status 値。
  String get statusValue => switch (this) {
        BoardLane.notStarted => 'not_started',
        BoardLane.inProgress => 'in_progress',
        BoardLane.blocked => 'blocked',
        BoardLane.completed => 'completed',
      };
}

/// status 文字列 → 列。未知の値・未着手系はすべて「未着手」へ寄せる。
BoardLane laneFromStatus(String status) => switch (status) {
      'in_progress' => BoardLane.inProgress,
      'blocked' => BoardLane.blocked,
      'completed' => BoardLane.completed,
      _ => BoardLane.notStarted,
    };

// ── エージェント (instance) ───────────────────────────────────

/// `instance` / `owner_instance` の生値を表示用に正規化する。
///
/// 許可値には別名 (codex1 / cx / co-pilot / ps1..ps6 等) が混在するため、
/// 表示上は同じエージェントへまとめる。未知の値はそのまま ID として扱い、
/// 新しいエージェントが増えてもコード変更なしで盤面に現れるようにする。
String normalizeAgentId(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return 'unknown';
  if (v.startsWith('codex') || v == 'cx') return 'codex';
  if (v.startsWith('claude')) return 'claude';
  if (v == 'co-pilot' || v == 'copilot') return 'copilot';
  if (v.startsWith('gemini')) return 'gemini';
  if (v.startsWith('ps')) return 'ps';
  if (v == 'usr' || v == 'human') return 'user';
  if (v == 'auto') return 'automation';
  return v;
}

/// 表示名。未知の ID は素の値を返す (新エージェントもそれらしく出る)。
String agentDisplayName(String agentId) => switch (agentId) {
      'claude' => 'Claude Code',
      'codex' => 'Codex',
      'gemini' => 'Gemini',
      'copilot' => 'GitHub Copilot',
      'antigravity' => 'Antigravity',
      'schedule' => 'Claude Schedule',
      'gha' => 'GitHub Actions',
      'automation' => 'Automation',
      'ps' => 'PowerShell 版',
      'vscode' => 'VSCode 版',
      'win' => 'Windows 版',
      'user' => '人間',
      'all' => '全体共有',
      'unknown' => '未割当',
      _ => agentId,
    };

/// エージェント色 (DESIGN.md の Orange + Indigo 系から決定的に割り当てる)。
Color agentColor(String agentId) => switch (agentId) {
      'claude' => const Color(0xFFFF6B35), // orange
      'codex' => const Color(0xFF3D5AFE), // indigo
      'gemini' => const Color(0xFF26C6DA), // cyan
      'copilot' => const Color(0xFF9C27B0), // purple
      'antigravity' => const Color(0xFF00E676), // green accent
      'schedule' => const Color(0xFFFFC107), // amber
      'gha' => const Color(0xFF7986CB), // indigo light
      'automation' => const Color(0xFF66BB6A),
      'ps' => const Color(0xFF29B6F6),
      'user' => const Color(0xFFEC407A),
      _ => const Color(0xFFB0B0B0),
    };

// ── カード / 集計 ─────────────────────────────────────────────

/// 盤面に置く 1 枚のカード。
class BoardCard {
  const BoardCard({
    required this.id,
    required this.title,
    required this.agentId,
    required this.lane,
    required this.progress,
    required this.priority,
    required this.categoryIcon,
    required this.updatedAt,
    this.issueNumber,
    this.issueUrl = '',
  });

  final String id;
  final String title;
  final String agentId;
  final BoardLane lane;
  final int progress; // 0-100
  final String priority;
  final String categoryIcon;
  final DateTime? updatedAt;
  final int? issueNumber;
  final String issueUrl;

  /// 最終更新からの経過表記 ("3分前" 等)。now は呼び出し側から渡す。
  String elapsedLabel(DateTime now) => formatElapsed(updatedAt, now);
}

/// 稼働中エージェントの集計 1 件。
class AgentSummary {
  const AgentSummary({
    required this.agentId,
    required this.inProgress,
    required this.blocked,
    required this.notStarted,
    required this.completedRecently,
    required this.currentTaskTitle,
  });

  final String agentId;
  final int inProgress;
  final int blocked;
  final int notStarted;
  final int completedRecently;
  final String currentTaskTitle;

  /// 進行中タスクを持っていれば「稼働中」。
  bool get isActive => inProgress > 0;

  int get total => inProgress + blocked + notStarted + completedRecently;
}

/// 盤面の表示状態全体。
class BoardSnapshot {
  const BoardSnapshot({
    required this.lanes,
    required this.hiddenNotStarted,
    required this.agents,
    required this.totalTasks,
  });

  /// 列 → その列に表示するカード。
  final Map<BoardLane, List<BoardCard>> lanes;

  /// 未着手列で上限を超えて隠したカード数 (「他 N 件」表示用)。
  final int hiddenNotStarted;

  final List<AgentSummary> agents;

  /// 盤面に載ったカードの総数。
  final int totalTasks;

  List<BoardCard> cardsOf(BoardLane lane) => lanes[lane] ?? const <BoardCard>[];
}

/// 完了列に残す時間窓 (直近 24 時間)。
const Duration completedWindow = Duration(hours: 24);

/// 未着手列の表示上限 (超過分は「他 N 件」)。
const int notStartedLimit = 20;

const Map<String, int> _priorityRank = <String, int>{
  'critical': 0,
  'high': 1,
  'medium': 2,
  'low': 3,
};

int _priorityOrder(String priority) =>
    _priorityRank[priority.toLowerCase()] ?? 2;

/// `wbs_tasks` の行 (Map) → カード。パースは防御的に行う。
BoardCard cardFromRow(Map<String, dynamic> row) {
  final rawAgent = (row['owner_instance'] as String?)?.trim().isNotEmpty == true
      ? row['owner_instance'] as String
      : (row['instance'] as String? ?? '');
  final progressRaw = row['progress'];
  final progress = progressRaw is int
      ? progressRaw
      : (progressRaw is num ? progressRaw.round() : 0);
  final issueRaw = row['github_issue_number'];
  final issueNumber = issueRaw is int
      ? issueRaw
      : (issueRaw is String ? int.tryParse(issueRaw) : null);

  return BoardCard(
    id: (row['id'] as String?) ?? '',
    title: (row['title'] as String?) ?? '(無題)',
    agentId: normalizeAgentId(rawAgent),
    lane: laneFromStatus((row['status'] as String?) ?? ''),
    progress: progress.clamp(0, 100),
    priority: (row['priority'] as String?) ?? 'medium',
    categoryIcon: (row['category_icon'] as String?) ?? '📋',
    updatedAt: row['updated_at'] is String
        ? DateTime.tryParse(row['updated_at'] as String)
        : null,
    issueNumber: issueNumber,
    issueUrl: (row['github_issue_url'] as String?) ?? '',
  );
}

/// 行群 → 盤面スナップショット。
///
/// スコープ (grill-me で確定):
///   - 未着手 / 進行中 / ブロック … 全件 (未着手のみ [notStartedLimit] で打ち切り)
///   - 完了 … 直近 [completedWindow] に更新されたものだけ
BoardSnapshot buildBoardSnapshot(
  List<Map<String, dynamic>> rows,
  DateTime now,
) {
  final cards = rows.map(cardFromRow).where((c) => c.id.isNotEmpty).toList();

  final lanes = <BoardLane, List<BoardCard>>{
    for (final lane in BoardLane.values) lane: <BoardCard>[],
  };

  for (final card in cards) {
    if (card.lane == BoardLane.completed) {
      final updated = card.updatedAt;
      // 完了は「今日 AI が片付けた分」だけを残す (時間経過で盤面から流れる)。
      if (updated == null || now.difference(updated) > completedWindow) {
        continue;
      }
    }
    lanes[card.lane]!.add(card);
  }

  // 進行中 / ブロック / 完了は「最近動いたものが上」。
  int byUpdatedDesc(BoardCard a, BoardCard b) {
    final ta = a.updatedAt;
    final tb = b.updatedAt;
    if (ta == null && tb == null) return a.title.compareTo(b.title);
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  }

  lanes[BoardLane.inProgress]!.sort(byUpdatedDesc);
  lanes[BoardLane.blocked]!.sort(byUpdatedDesc);
  lanes[BoardLane.completed]!.sort(byUpdatedDesc);

  // 未着手は優先度順 → 同順位は最近更新順。
  lanes[BoardLane.notStarted]!.sort((a, b) {
    final p = _priorityOrder(a.priority).compareTo(_priorityOrder(b.priority));
    if (p != 0) return p;
    return byUpdatedDesc(a, b);
  });

  final notStarted = lanes[BoardLane.notStarted]!;
  final hidden = notStarted.length > notStartedLimit
      ? notStarted.length - notStartedLimit
      : 0;
  if (hidden > 0) {
    lanes[BoardLane.notStarted] = notStarted.take(notStartedLimit).toList();
  }

  final visible = lanes.values.fold<int>(0, (sum, list) => sum + list.length);

  return BoardSnapshot(
    lanes: lanes,
    hiddenNotStarted: hidden,
    agents: summarizeAgents(lanes),
    totalTasks: visible,
  );
}

/// 盤面に出ているカードから、エージェント別の稼働サマリを作る。
///
/// 実データに現れたエージェントだけを返すので、新しい instance 値が
/// 増えてもコード変更なしで一覧に出る。稼働中 (進行中あり) を先頭へ。
List<AgentSummary> summarizeAgents(Map<BoardLane, List<BoardCard>> lanes) {
  final byAgent = <String, List<BoardCard>>{};
  for (final entry in lanes.entries) {
    for (final card in entry.value) {
      byAgent.putIfAbsent(card.agentId, () => <BoardCard>[]).add(card);
    }
  }

  final summaries = byAgent.entries.map((entry) {
    final cards = entry.value;
    final inProgress =
        cards.where((c) => c.lane == BoardLane.inProgress).toList();
    // 現在のタスク = 進行中のうち最も新しく更新されたもの。
    inProgress.sort((a, b) {
      final ta = a.updatedAt;
      final tb = b.updatedAt;
      if (ta == null || tb == null) return 0;
      return tb.compareTo(ta);
    });
    return AgentSummary(
      agentId: entry.key,
      inProgress: inProgress.length,
      blocked: cards.where((c) => c.lane == BoardLane.blocked).length,
      notStarted: cards.where((c) => c.lane == BoardLane.notStarted).length,
      completedRecently:
          cards.where((c) => c.lane == BoardLane.completed).length,
      currentTaskTitle: inProgress.isEmpty ? '' : inProgress.first.title,
    );
  }).toList();

  summaries.sort((a, b) {
    // 稼働中を上へ → 進行中件数の多い順 → 総件数 → 名前順で安定化。
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    if (a.inProgress != b.inProgress) {
      return b.inProgress.compareTo(a.inProgress);
    }
    if (a.total != b.total) return b.total.compareTo(a.total);
    return a.agentId.compareTo(b.agentId);
  });
  return summaries;
}

/// 経過時間の表記。更新時刻が無い場合は空文字。
String formatElapsed(DateTime? updatedAt, DateTime now) {
  if (updatedAt == null) return '';
  final diff = now.difference(updatedAt);
  if (diff.isNegative) return 'たった今';
  if (diff.inSeconds < 60) return 'たった今';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';
  return '${diff.inDays}日前';
}
