import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/agent_board_models.dart';
import '../services/agent_board_service.dart';
import '../theme/design_tokens.dart';

/// AI エージェント カンバンボード。
///
/// Claude Code / Codex / Gemini などの AI エージェントが `wbs_tasks` 上の
/// タスクをこなしていく様子を、動的に更新されるカンバンで眺めるページ。
/// カードの移動は演出ではなく **実データの状態遷移** で、Supabase Realtime
/// により変更が届いた瞬間に盤面が動く (60 秒のフォールバック再取得つき)。
///
/// WBS には未公開の開発計画が含まれるため **ログイン済みユーザー限定**。
class AgentBoardPage extends StatefulWidget {
  const AgentBoardPage({super.key, this.service});

  /// データ供給 (テスト時に差し替え可能)。
  final AgentBoardService? service;

  @override
  State<AgentBoardPage> createState() => _AgentBoardPageState();
}

class _AgentBoardPageState extends State<AgentBoardPage> {
  late final AgentBoardService _service;

  BoardSnapshot? _snapshot;
  bool _loading = true;
  String _error = '';
  DateTime _now = DateTime.now();
  DateTime? _lastUpdatedAt;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AgentBoardService();
    if (_service.isSignedIn) {
      _reload();
      _service.subscribe(_reload);
      // 「◯分前」表示を進めるための時計 (盤面データは触らない)。
      _clock = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final rows = await _service.fetchRows();
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _snapshot = buildBoardSnapshot(rows, now);
        _now = now;
        _lastUpdatedAt = now;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'タスクの取得に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.background,
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.view_kanban_outlined,
              color: DesignTokens.orange,
              size: 20,
            ),
            SizedBox(width: DesignTokens.space8),
            Text(
              'AIエージェント ボード',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (_service.isSignedIn)
            IconButton(
              tooltip: '再読み込み',
              onPressed: _reload,
              icon: const Icon(
                Icons.refresh,
                size: 20,
                color: DesignTokens.textSecondary,
              ),
            ),
          const SizedBox(width: DesignTokens.space8),
        ],
      ),
      body: !_service.isSignedIn
          ? _buildSignInGate()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: DesignTokens.orange,
                  ),
                )
              : _buildBoard(),
    );
  }

  // ── 未ログイン導線 ─────────────────────────────────────────
  Widget _buildSignInGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 40,
              color: DesignTokens.textTertiary,
            ),
            const SizedBox(height: DesignTokens.space16),
            const Text(
              'この機能はログインが必要です',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            const Text(
              'AIエージェントが進めている開発タスクを表示するため、\n'
              'ログインしたユーザーのみ閲覧できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: DesignTokens.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DesignTokens.space24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.orange,
              ),
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('ログインする'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 盤面 ───────────────────────────────────────────────────
  Widget _buildBoard() {
    final snapshot = _snapshot;
    if (_error.isNotEmpty && snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DesignTokens.red),
          ),
        ),
      );
    }
    if (snapshot == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBar(snapshot),
              const SizedBox(height: DesignTokens.space16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: _buildAgentPanel(snapshot)),
                    const SizedBox(width: DesignTokens.space12),
                    Expanded(child: _buildLanes(snapshot, wide)),
                  ],
                )
              else ...[
                _buildAgentPanel(snapshot),
                const SizedBox(height: DesignTokens.space12),
                _buildLanes(snapshot, wide),
              ],
            ],
          ),
        );
      },
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      );

  Widget _buildStatusBar(BoardSnapshot snapshot) {
    final active = snapshot.agents.where((a) => a.isActive).length;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space12,
      ),
      decoration: _cardDecoration,
      child: Wrap(
        spacing: DesignTokens.space12,
        runSpacing: DesignTokens.space8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _pill('$active エージェント稼働中', DesignTokens.green, filled: true),
          _pill(
            '${snapshot.totalTasks} タスク表示中',
            DesignTokens.indigoLight,
          ),
          _meta(
            '最終更新',
            _lastUpdatedAt == null ? '—' : formatElapsed(_lastUpdatedAt, _now),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: DesignTokens.green),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : DesignTokens.surface3,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            fontSize: 11,
            color: DesignTokens.textTertiary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DesignTokens.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── エージェント一覧 ───────────────────────────────────────
  Widget _buildAgentPanel(BoardSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AIエージェント',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          if (snapshot.agents.isEmpty)
            const Text(
              '担当エージェントなし',
              style: TextStyle(
                fontSize: 12,
                color: DesignTokens.textTertiary,
              ),
            )
          else
            for (final agent in snapshot.agents) _agentTile(agent),
        ],
      ),
    );
  }

  Widget _agentTile(AgentSummary agent) {
    final color = agentColor(agent.agentId);
    final name = agentDisplayName(agent.agentId);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (agent.isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: DesignTokens.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DesignTokens.surface1,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  agent.isActive
                      ? '進行中 ${agent.inProgress}'
                          '${agent.blocked > 0 ? ' / ブロック ${agent.blocked}' : ''}'
                      : '待機中'
                          '${agent.blocked > 0 ? ' (ブロック ${agent.blocked})' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: agent.isActive ? color : DesignTokens.textTertiary,
                  ),
                ),
                if (agent.currentTaskTitle.isNotEmpty)
                  Text(
                    agent.currentTaskTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── カンバン ───────────────────────────────────────────────
  Widget _buildLanes(BoardSnapshot snapshot, bool wide) {
    const lanes = BoardLane.values;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < lanes.length; i++) ...[
            Expanded(child: _laneColumn(snapshot, lanes[i])),
            if (i != lanes.length - 1)
              const SizedBox(width: DesignTokens.space8),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (final lane in lanes) ...[
          _laneColumn(snapshot, lane),
          const SizedBox(height: DesignTokens.space8),
        ],
      ],
    );
  }

  Color _laneColor(BoardLane lane) => switch (lane) {
        BoardLane.notStarted => DesignTokens.textSecondary,
        BoardLane.inProgress => DesignTokens.orange,
        BoardLane.blocked => DesignTokens.red,
        BoardLane.completed => DesignTokens.green,
      };

  Widget _laneColumn(BoardSnapshot snapshot, BoardLane lane) {
    final cards = snapshot.cardsOf(lane);
    final color = _laneColor(lane);
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: DesignTokens.space4,
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  lane.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: DesignTokens.surface3,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusCircle),
                  ),
                  child: Text(
                    '${cards.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          if (cards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DesignTokens.space16),
              child: Text(
                '—',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.textDisabled),
              ),
            )
          else
            for (final card in cards) _taskCard(card),
          if (lane == BoardLane.notStarted && snapshot.hiddenNotStarted > 0)
            Padding(
              padding: const EdgeInsets.only(top: DesignTokens.space4),
              child: Text(
                '他 ${snapshot.hiddenNotStarted} 件',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: DesignTokens.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _taskCard(BoardCard card) {
    final color = agentColor(card.agentId);
    final elapsed = card.elapsedLabel(_now);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: card.lane == BoardLane.blocked
              ? DesignTokens.red.withValues(alpha: 0.5)
              : DesignTokens.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(card.categoryIcon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 進捗バー (更新のたびに伸びるのが見える)。
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
            child: LinearProgressIndicator(
              value: card.progress / 100,
              minHeight: 4,
              backgroundColor: DesignTokens.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircle),
                ),
                child: Text(
                  agentDisplayName(card.agentId),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${card.progress}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textSecondary,
                ),
              ),
              const Spacer(),
              if (elapsed.isNotEmpty)
                Text(
                  elapsed,
                  style: const TextStyle(
                    fontSize: 10,
                    color: DesignTokens.textTertiary,
                  ),
                ),
            ],
          ),
          if (card.issueNumber != null && card.issueUrl.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => unawaited(
                  launchUrl(
                    Uri.parse(card.issueUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                child: Text(
                  '#${card.issueNumber}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: DesignTokens.indigoLight,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
