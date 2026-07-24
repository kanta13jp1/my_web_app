import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/autonomous_ops_service.dart';
import '../theme/design_tokens.dart';

/// OMOCHA WORKS — 自律オペレーションコンソール。
///
/// 「何をしているかは分からないけれど、AI が自動でガシガシとタスクを
/// こなしていく」様子を眺めて楽しむ、アンビエントな運用ダッシュボード。
///
/// バックエンドには依存せず、ページ内の [Timer] 駆動シミュレーションで
/// AI エージェントがカンバンを前進させ、KPI・活動ログ・スループットが
/// リアルタイムに変化する。見ているだけで「何かが進んでいる」感覚を得る、
/// という体験そのものが本機能の価値 (= IMBUE パターンの AI 体験設計)。
class AutonomousOpsConsolePage extends StatefulWidget {
  const AutonomousOpsConsolePage({super.key, this.service});

  /// 実データ取得サービス (テスト時に差し替え可能)。
  /// null の場合、ログイン済みオーナーなら実データ、それ以外は
  /// シミュレーション表示になる。
  final AutonomousOpsService? service;

  @override
  State<AutonomousOpsConsolePage> createState() =>
      _AutonomousOpsConsolePageState();
}

// ── カンバンの列 ─────────────────────────────────────────────
enum _Lane { backlog, progress, review, done }

extension _LaneLabel on _Lane {
  String get label => switch (this) {
        _Lane.backlog => 'バックログ',
        _Lane.progress => '進行中',
        _Lane.review => 'レビュー',
        _Lane.done => '完了',
      };
}

// ── AI エージェント ─────────────────────────────────────────
class _OpsAgent {
  final String initial;
  final String name;
  final String role;
  final Color color;

  const _OpsAgent({
    required this.initial,
    required this.name,
    required this.role,
    required this.color,
  });
}

// ── タスク ──────────────────────────────────────────────────
class _OpsTask {
  _OpsTask({
    required this.code,
    required this.dept,
    required this.title,
    required this.valueYen,
    required this.lane,
    this.agent,
  });

  final String code;
  final String dept;
  final String title;
  final int valueYen;
  _Lane lane;
  _OpsAgent? agent;
}

// ── 活動ログ ────────────────────────────────────────────────
class _Activity {
  const _Activity({
    required this.text,
    required this.time,
    required this.color,
  });

  final String text;
  final String time;
  final Color color;
}

class _AutonomousOpsConsolePageState extends State<AutonomousOpsConsolePage> {
  // 決定的な擬似乱数 (見た目のゆらぎ用 / 実データではない)。
  final math.Random _rand = math.Random(20260722);

  Timer? _clock; // 1 秒ごとの時計・稼働時間
  Timer? _engine; // タスク遷移エンジン (シミュレーション / 実データ間の動き)
  Timer? _poll; // 実データポーリング (~20 秒)
  bool _paused = false;

  late final AutonomousOpsService _service;

  // 実データモード: true=GitHub Actions 実データ表示 / false=シミュレーション。
  bool _realMode = false;
  // オーナーだが GH_ACTIONS_READ_TOKEN 未設定 (構成ヒント表示用)。
  bool _ownerUnconfigured = false;

  int _seconds = 15 * 3600 + 51 * 60 + 22; // 壁時計 (15:51:22 起点)
  int _uptimeSeconds = 127 * 86400 + 4 * 3600 + 12 * 60 + 54; // 連続稼働

  // KPI
  int _completedToday = 128;
  double _automatedHours = 39.9;
  int _revenueImpact = 2983000;
  double _slaCompliance = 99.4;
  double _throughput = 45.6;
  final List<double> _throughputHistory =
      List<double>.generate(40, (i) => 30 + 12 * math.sin(i / 3.2) + (i % 5));

  int _taskSeq = 1853;

  static const List<_OpsAgent> _agents = <_OpsAgent>[
    _OpsAgent(
      initial: 'H',
      name: 'HAYATE',
      role: '開発・自動化',
      color: DesignTokens.orange,
    ),
    _OpsAgent(
      initial: 'K',
      name: 'KANNA',
      role: '品質・レビュー',
      color: DesignTokens.indigo,
    ),
    _OpsAgent(
      initial: 'M',
      name: 'MIYA',
      role: 'データ分析',
      color: Color(0xFF26C6DA),
    ),
    _OpsAgent(
      initial: 'B',
      name: 'BOLT',
      role: 'インフラ監視',
      color: DesignTokens.amber,
    ),
    _OpsAgent(
      initial: 'S',
      name: 'SHIORI',
      role: '業務・文書',
      color: Color(0xFFEC407A),
    ),
  ];

  // タスクの元ネタ (部署, タイトル)。
  static const List<List<String>> _templates = <List<String>>[
    <String>['経理', '請求書PDFの自動仕分け'],
    <String>['分析', '翌月の需要予測モデル更新'],
    <String>['経理', '未入金アラートの送付準備'],
    <String>['開発', 'セキュリティパッチの適用確認'],
    <String>['マーケ', 'LP見出しのA/Bテスト集計'],
    <String>['業務', '障害レポートの自動要約'],
    <String>['経理', '経費精算56件の承認処理'],
    <String>['分析', '解約リスクスコアの再計算'],
    <String>['マーケ', '競合価格の巡回モニタリング'],
    <String>['インフラ', '夜間バッチの正常終了確認'],
    <String>['業務', '問い合わせ一次対応の下書き'],
    <String>['分析', 'KPIダッシュボードの日次更新'],
    <String>['経理', '在庫差異レポートの生成'],
    <String>['マーケ', '新規リードのスコアリング'],
    <String>['インフラ', 'ログ異常検知のトリアージ'],
    <String>['開発', 'API後方互換テストの実行'],
  ];

  final List<_OpsTask> _tasks = <_OpsTask>[];
  final List<_Activity> _activities = <_Activity>[];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AutonomousOpsService();
    _seedBoard();
    _startTimers();
    // ログイン済みオーナーなら実データ取得を試みる (失敗時はシミュレーション継続)。
    if (_service.isSignedIn) {
      _pollOnce();
      _poll = Timer.periodic(
        const Duration(seconds: 20),
        (_) {
          if (_paused || !mounted) return;
          _pollOnce();
        },
      );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _engine?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || !mounted) return;
      setState(() {
        _seconds++;
        _uptimeSeconds++;
      });
    });
    _engine = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_paused || !mounted) return;
      setState(_advanceBoard);
    });
  }

  /// 実データを 1 回取得し、live なら実データモードへ切り替える。
  Future<void> _pollOnce() async {
    final dto = await _service.fetch();
    if (!mounted || dto == null) return;
    setState(() {
      if (dto.live) {
        _applySnapshot(dto);
        _realMode = true;
        _ownerUnconfigured = false;
      } else {
        // オーナーだがトークン未構成 → シミュレーション継続 + ヒント表示。
        _ownerUnconfigured = !dto.configured;
      }
    });
  }

  /// 実データスナップショットを盤面へ反映する。
  void _applySnapshot(OpsSnapshotDto dto) {
    _tasks
      ..clear()
      ..addAll(dto.tasks.map((t) => _OpsTask(
            code: t.code,
            dept: t.dept,
            title: t.title,
            valueYen: t.valueYen,
            lane: _laneFromString(t.lane),
            agent: _agentById(t.agentId),
          )));
    _activities
      ..clear()
      ..addAll(dto.activities.map((a) => _Activity(
            text: a.text,
            time: a.time,
            color: _agentById(a.agentId)?.color ?? DesignTokens.textSecondary,
          )));
    _completedToday = dto.completedToday;
    _automatedHours = dto.automatedHours;
    _revenueImpact = dto.revenueImpact;
    _slaCompliance = dto.slaCompliance;
    if (dto.throughput > 0) _throughput = dto.throughput;
    if (dto.throughputHistory.isNotEmpty) {
      _throughputHistory
        ..clear()
        ..addAll(dto.throughputHistory);
    }
  }

  _OpsAgent? _agentById(String? id) {
    if (id == null) return null;
    for (final a in _agents) {
      if (a.initial == id) return a;
    }
    return null;
  }

  _Lane _laneFromString(String lane) => switch (lane) {
        'backlog' => _Lane.backlog,
        'progress' => _Lane.progress,
        'review' => _Lane.review,
        'done' => _Lane.done,
        _ => _Lane.backlog,
      };

  void _seedBoard() {
    // 初期配置 (スクリーンショットに近い状態)。
    _addTask('経理', '請求書PDFの自動仕分け', 67000, _Lane.backlog);
    _addTask('マーケ', 'LP見出しのA/Bテスト集計', 63000, _Lane.backlog);
    _addTask(
      '分析',
      '翌月の需要予測モデル更新',
      70000,
      _Lane.progress,
      agent: _agents[2],
    );
    _addTask(
      '経理',
      '未入金アラートの送付準備',
      45000,
      _Lane.progress,
      agent: _agents[3],
    );
    _addTask(
      '開発',
      'セキュリティパッチの適用確認',
      31000,
      _Lane.progress,
      agent: _agents[1],
    );
    _addTask('業務', '障害レポートの自動要約', 55000, _Lane.review, agent: _agents[4]);
    _addTask('マーケ', 'LP見出しのA/Bテスト集計', 136000, _Lane.done);
    _addTask('分析', '解約リスクスコアの再計算', 25000, _Lane.done);
    _addTask('マーケ', '競合価格の巡回モニタリング', 54000, _Lane.done);

    _log(
      '自律モード LEVEL 3 で稼働中 — 人間の承認は不要です',
      const Color(0xFF9E9E9E),
    );
  }

  _OpsTask _addTask(
    String dept,
    String title,
    int value,
    _Lane lane, {
    _OpsAgent? agent,
  }) {
    final task = _OpsTask(
      code: 'OW-${_taskSeq--}',
      dept: dept,
      title: title,
      valueYen: value,
      lane: lane,
      agent: agent,
    );
    _tasks.add(task);
    return task;
  }

  List<_OpsTask> _lane(_Lane lane) =>
      _tasks.where((t) => t.lane == lane).toList();

  _OpsAgent _randomAgent() => _agents[_rand.nextInt(_agents.length)];

  /// エンジン 1 tick: いずれかの列を 1 手進め、KPI と活動ログを更新する。
  ///
  /// 実データモードでは盤面はポーリングで更新されるため、ここでは
  /// スパークラインの"動き"だけを継続させ、実タスクは変更しない。
  void _advanceBoard() {
    if (_realMode) {
      _jitterThroughput();
      return;
    }
    final review = _lane(_Lane.review);
    final progress = _lane(_Lane.progress);
    final backlog = _lane(_Lane.backlog);

    final roll = _rand.nextDouble();

    if (review.isNotEmpty && (roll < 0.34 || review.length > 1)) {
      // レビュー → 完了
      final t = review.first;
      t.lane = _Lane.done;
      final approver = _randomAgent();
      _completedToday++;
      _revenueImpact += t.valueYen;
      _automatedHours += 0.1 + _rand.nextDouble() * 0.4;
      _log('${approver.name} が承認 — 「${t.title}」完了', approver.color);
      _trimDone();
    } else if (progress.isNotEmpty && (roll < 0.64 || progress.length > 4)) {
      // 進行中 → レビュー
      final t = progress[_rand.nextInt(progress.length)];
      t.lane = _Lane.review;
      final reviewer = _agents[1]; // KANNA = 品質・レビュー
      t.agent = reviewer;
      _log('${reviewer.name} が「${t.title}」のレビューを開始', reviewer.color);
    } else if (backlog.isNotEmpty && progress.length < 5) {
      // バックログ → 進行中 (エージェント着手)
      final t = backlog.first;
      t.lane = _Lane.progress;
      final agent = _randomAgent();
      t.agent = agent;
      _log('${agent.name} が「${t.title}」に着手', agent.color);
    } else if (backlog.length < 3) {
      // 新規タスク発生
      final tpl = _templates[_rand.nextInt(_templates.length)];
      final value = (2 + _rand.nextInt(14)) * 10000 + _rand.nextInt(10) * 1000;
      _addTask(tpl[0], tpl[1], value, _Lane.backlog);
      _log(
        '新規タスク「${tpl[1]}」がバックログに追加',
        const Color(0xFF9E9E9E),
      );
    }

    // KPI のゆらぎ。
    _slaCompliance = (98.6 + _rand.nextDouble() * 1.3).clamp(97.0, 99.9);
    _jitterThroughput();
  }

  /// スパークラインを少しだけ動かす (フェッチ間 / シミュレーション共通)。
  void _jitterThroughput() {
    if (_realMode) {
      // 実データの直近値の周りで軽く揺らし、"生きてる感"を維持する。
      final base = _throughput <= 0 ? 1.0 : _throughput;
      _throughput = (base + (_rand.nextDouble() - 0.5) * base * 0.15)
          .clamp(0, double.infinity);
    } else {
      _throughput = 36 + _rand.nextDouble() * 16;
    }
    _throughputHistory.add(_throughput);
    if (_throughputHistory.length > 40) _throughputHistory.removeAt(0);
  }

  // 完了列は直近数件のみ表示 (古いものはアーカイブ扱いで除去)。
  void _trimDone() {
    final done = _lane(_Lane.done);
    if (done.length > 3) {
      _tasks.remove(done.first);
    }
  }

  void _log(String text, Color color) {
    _activities.insert(
      0,
      _Activity(text: text, time: _fmtClock(_seconds), color: color),
    );
    if (_activities.length > 40) _activities.removeLast();
  }

  // ── フォーマッタ ─────────────────────────────────────────
  String _fmtClock(int totalSeconds) {
    final s = totalSeconds % 86400;
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  String _fmtUptime() {
    final days = _uptimeSeconds ~/ 86400;
    return '$days日 ${_fmtClock(_uptimeSeconds)}';
  }

  String _fmtYen(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '¥$buf';
  }

  Color _deptColor(String dept) => switch (dept) {
        '経理' => DesignTokens.green,
        'マーケ' => DesignTokens.orange,
        '分析' => const Color(0xFF26C6DA),
        '開発' => DesignTokens.indigoLight,
        '品質' => DesignTokens.indigo,
        'インフラ' => DesignTokens.amber,
        '業務' => const Color(0xFFEC407A),
        _ => DesignTokens.textSecondary,
      };

  // ── ビルド ───────────────────────────────────────────────
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
              Icons.auto_awesome_motion,
              color: DesignTokens.orange,
              size: 20,
            ),
            SizedBox(width: DesignTokens.space8),
            Text(
              'OMOCHA WORKS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: DesignTokens.space8),
            Flexible(
              child: Text(
                '自律オペレーションコンソール',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _paused = !_paused),
            icon: Icon(
              _paused ? Icons.play_arrow : Icons.pause,
              size: 18,
              color: _paused ? DesignTokens.green : DesignTokens.textSecondary,
            ),
            label: Text(
              _paused ? '再開' : '一時停止',
              style: TextStyle(
                color:
                    _paused ? DesignTokens.green : DesignTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBar(),
                const SizedBox(height: DesignTokens.space16),
                _buildKpiRow(wide),
                const SizedBox(height: DesignTokens.space16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 220, child: _buildAgentRoster()),
                      const SizedBox(width: DesignTokens.space12),
                      Expanded(child: _buildBoard(wide)),
                      const SizedBox(width: DesignTokens.space12),
                      SizedBox(width: 280, child: _buildActivityFeed()),
                    ],
                  )
                else ...[
                  _buildAgentRoster(),
                  const SizedBox(height: DesignTokens.space12),
                  _buildBoard(wide),
                  const SizedBox(height: DesignTokens.space12),
                  _buildActivityFeed(),
                ],
                const SizedBox(height: DesignTokens.space16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 220, child: _buildSystemState()),
                      const SizedBox(width: DesignTokens.space12),
                      Expanded(child: _buildThroughput()),
                    ],
                  )
                else ...[
                  _buildSystemState(),
                  const SizedBox(height: DesignTokens.space12),
                  _buildThroughput(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      );

  Widget _buildStatusBar() {
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
          _pill('production', DesignTokens.green, filled: true),
          _pill('Q3 スプリント S2', DesignTokens.indigoLight),
          if (_realMode)
            _pill('実データ · GitHub Actions', DesignTokens.green, filled: true)
          else if (_ownerUnconfigured)
            _pill('シミュレーション · トークン未設定', DesignTokens.amber)
          else
            _pill('シミュレーション', DesignTokens.textSecondary),
          _metaText('連続稼働', _fmtUptime()),
          _metaText('現在時刻', _fmtClock(_seconds)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _paused ? Icons.pause_circle : Icons.circle,
                size: 10,
                color: _paused ? DesignTokens.amber : DesignTokens.green,
              ),
              const SizedBox(width: 6),
              Text(
                _paused ? '一時停止中' : 'LIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _paused ? DesignTokens.amber : DesignTokens.green,
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

  Widget _metaText(String label, String value) {
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
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(bool wide) {
    final cards = <Widget>[
      _kpiCard(
        '本日の完了タスク',
        '$_completedToday',
        '件',
        '+11%',
        DesignTokens.orange,
      ),
      _kpiCard(
        '自動化された作業時間',
        _automatedHours.toStringAsFixed(1),
        'h',
        '+17%',
        DesignTokens.indigoLight,
      ),
      _kpiCard(
        '売上インパクト',
        _fmtYen(_revenueImpact),
        '',
        '+18%',
        DesignTokens.green,
      ),
      _kpiCard(
        'SLA遵守率',
        _slaCompliance.toStringAsFixed(1),
        '%',
        '+0.3pt',
        const Color(0xFF26C6DA),
      ),
    ];
    if (wide) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i != cards.length - 1)
              const SizedBox(width: DesignTokens.space12),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1)
            const SizedBox(height: DesignTokens.space12),
        ],
      ],
    );
  }

  Widget _kpiCard(
    String label,
    String value,
    String unit,
    String delta,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_up,
                size: 16,
                color: DesignTokens.green,
              ),
              Text(
                delta,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    color: DesignTokens.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _SparklinePainter(_throughputHistory, color),
              size: const Size(double.infinity, 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRoster() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AIエージェント',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
              const Spacer(),
              _pill(
                '${_agents.length} 稼働中',
                DesignTokens.green,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          for (final agent in _agents) _agentTile(agent),
        ],
      ),
    );
  }

  Widget _agentTile(_OpsAgent agent) {
    // このエージェントが今どのタスクに着手しているか。
    final active = _tasks
        .where(
          (t) =>
              t.agent == agent &&
              (t.lane == _Lane.progress || t.lane == _Lane.review),
        )
        .toList();
    final statusText = active.isEmpty
        ? '待機中'
        : '${active.first.lane == _Lane.review ? 'レビュー' : '作業'}中 — ${active.first.title}';
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: agent.color.withValues(alpha: 0.2),
                child: Text(
                  agent.initial,
                  style: TextStyle(
                    color: agent.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (active.isNotEmpty)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
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
                Row(
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      agent.role,
                      style: const TextStyle(
                        fontSize: 10,
                        color: DesignTokens.textTertiary,
                      ),
                    ),
                  ],
                ),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: active.isEmpty
                        ? DesignTokens.textTertiary
                        : agent.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(bool wide) {
    const lanes = _Lane.values;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < lanes.length; i++) ...[
            Expanded(child: _laneColumn(lanes[i])),
            if (i != lanes.length - 1)
              const SizedBox(width: DesignTokens.space8),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (final lane in lanes) ...[
          _laneColumn(lane),
          const SizedBox(height: DesignTokens.space8),
        ],
      ],
    );
  }

  Widget _laneColumn(_Lane lane) {
    final items = _lane(lane);
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
                    '${items.length}',
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
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DesignTokens.space16),
              child: Text(
                '—',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.textDisabled),
              ),
            )
          else
            for (final task in items) _taskCard(task, lane),
        ],
      ),
    );
  }

  Widget _taskCard(_OpsTask task, _Lane lane) {
    final deptColor = _deptColor(task.dept);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: lane == _Lane.review
              ? DesignTokens.indigo.withValues(alpha: 0.6)
              : DesignTokens.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: deptColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.dept,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: deptColor,
                  ),
                ),
              ),
              const Spacer(),
              if (lane == _Lane.done)
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: DesignTokens.green,
                ),
              if (lane == _Lane.review)
                const Icon(
                  Icons.drag_indicator,
                  size: 14,
                  color: DesignTokens.indigoLight,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: DesignTokens.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                task.code,
                style: const TextStyle(
                  fontSize: 10,
                  color: DesignTokens.textTertiary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                _fmtYen(task.valueYen),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (task.agent != null &&
              (lane == _Lane.progress || lane == _Lane.review)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: task.agent!.color.withValues(alpha: 0.16),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircle),
                ),
                child: Text(
                  '${task.agent!.name} ${lane == _Lane.review ? 'レビュー中' : '作業中'}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: task.agent!.color,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'アクティビティ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
              Spacer(),
              Icon(Icons.circle, size: 8, color: DesignTokens.red),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          // 直近の活動のみ表示 (ページ全体が縦スクロールするため個別の
          // スクロールビューは持たせない = intrinsic 制約の落とし穴を回避)。
          for (final a in _activities.take(16)) _activityRow(a),
        ],
      ),
    );
  }

  Widget _activityRow(_Activity a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: a.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesignTokens.textOnDark,
                    height: 1.35,
                  ),
                ),
                Text(
                  a.time,
                  style: const TextStyle(
                    fontSize: 10,
                    color: DesignTokens.textTertiary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemState() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'システム状態',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          _gauge('CPU', 0.29, DesignTokens.indigo),
          _gauge('メモリ', 0.56, DesignTokens.orange),
          _gauge('APIクォータ', 0.27, DesignTokens.green),
        ],
      ),
    );
  }

  Widget _gauge(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: DesignTokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: DesignTokens.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThroughput() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '処理スループット',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'タスク/時',
                style:
                    TextStyle(fontSize: 11, color: DesignTokens.textTertiary),
              ),
              const Spacer(),
              Text(
                _throughput.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.orange,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _ThroughputPainter(_throughputHistory),
              size: const Size(double.infinity, 120),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI カード用スパークライン ─────────────────────────────
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.data, this.color);

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxV = data.reduce(math.max);
    final minV = data.reduce(math.min);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final dx = size.width / (data.length - 1);

    final path = Path();
    final fill = Path();
    for (int i = 0; i < data.length; i++) {
      final x = dx * i;
      final y = size.height - ((data[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => true;
}

// ── スループット折れ線 ─────────────────────────────────────
class _ThroughputPainter extends CustomPainter {
  _ThroughputPainter(this.data);

  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    // 目盛り線。
    final grid = Paint()
      ..color = DesignTokens.divider
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (data.length < 2) return;

    const maxV = 60.0;
    const minV = 20.0;
    const range = maxV - minV;
    final dx = size.width / (data.length - 1);

    final path = Path();
    final fill = Path();
    for (int i = 0; i < data.length; i++) {
      final x = dx * i;
      final clamped = data[i].clamp(minV, maxV);
      final y = size.height - ((clamped - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DesignTokens.indigo.withValues(alpha: 0.32),
            DesignTokens.indigo.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = DesignTokens.indigoLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // 末尾の現在値ポイント。
    final lastX = size.width;
    final lastClamped = data.last.clamp(minV, maxV);
    final lastY = size.height - ((lastClamped - minV) / range) * size.height;
    canvas.drawCircle(
      Offset(lastX - 1, lastY),
      3,
      Paint()..color = DesignTokens.orange,
    );
  }

  @override
  bool shouldRepaint(covariant _ThroughputPainter old) => true;
}
