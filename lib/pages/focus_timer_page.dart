import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 集中タイマーページ (ポモドーロ)
/// focus-timer Edge Function と連携して集中セッションを管理
/// Forest / Focusmate 競合
class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['timer', 'stats'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // ---- timer state ----
  Timer? _ticker;
  bool _isRunning = false;
  bool _isBreak = false;
  int _secondsLeft = 25 * 60;
  int _workMinutes = 25;
  int _breakMinutes = 5;
  int _pomodoroCount = 0;
  String? _activeSessionId;
  final _taskController = TextEditingController();

  // ---- stats state ----
  bool _loadingStats = true;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic> _stats = {};

  static const _presets = [
    ('25 / 5', 25, 5),
    ('50 / 10', 50, 10),
    ('90 / 20', 90, 20),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && mounted) _fetchStats();
    });
    _fetchStats();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  // ---- timer controls ----

  Future<void> _start() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnack('ログインが必要です');
      return;
    }
    if (_isBreak) {
      _startCountdown();
      return;
    }
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'focus.start',
          'task_label':
              _taskController.text.isEmpty ? '集中作業' : _taskController.text,
          'duration_minutes': _workMinutes,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final session = data['session'];
        if (session is Map<String, dynamic>) {
          _activeSessionId = session['id']?.toString();
        }
      }
    } catch (_) {
      // ローカル動作のみ続行
    }
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _resume() => _startCountdown();

  Future<void> _stop() async {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _secondsLeft = _workMinutes * 60;
    });
    if (_activeSessionId != null) {
      try {
        await _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'focus.cancel', 'session_id': _activeSessionId},
        );
      } catch (_) {}
      _activeSessionId = null;
    }
    await _fetchStats();
  }

  Future<void> _onTimerComplete() async {
    _ticker?.cancel();
    setState(() => _isRunning = false);
    if (!_isBreak && _activeSessionId != null) {
      try {
        await _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'focus.complete', 'session_id': _activeSessionId},
        );
        _activeSessionId = null;
      } catch (_) {}
    }
    setState(() {
      if (_isBreak) {
        _isBreak = false;
        _secondsLeft = _workMinutes * 60;
      } else {
        _pomodoroCount++;
        _isBreak = true;
        _secondsLeft = _breakMinutes * 60;
      }
    });
    _showSessionCompleteDialog();
    await _fetchStats();
  }

  void _showSessionCompleteDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isBreak ? '休憩タイム！' : '集中セッション完了！'),
        content: Text(
          _isBreak
              ? '$_breakMinutes分の休憩を取りましょう。'
              : 'お疲れ様でした。$_pomodoroCountポモドーロ達成！',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startCountdown();
            },
            child: Text(_isBreak ? '休憩開始' : '続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('あとで'),
          ),
        ],
      ),
    );
  }

  // ---- stats ----

  Future<void> _fetchStats() async {
    if (!mounted) return;
    if (_supabase.auth.currentUser == null) {
      setState(() => _loadingStats = false);
      return;
    }
    setState(() => _loadingStats = true);
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'focus.stats', 'days': 30},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _sessions =
                (data['sessions'] as List? ?? []).cast<Map<String, dynamic>>();
            _stats = data['stats'] as Map<String, dynamic>? ?? {};
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _sessions = []);
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- formatting ----

  String get _formattedTime {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = (_isBreak ? _breakMinutes : _workMinutes) * 60;
    return 1 - (_secondsLeft / total);
  }

  Color get _timerColor =>
      _isBreak ? const Color(0xFF43A047) : const Color(0xFFFF6B35);

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('集中タイマー'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timer), text: 'タイマー'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimerTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildTimerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // mode badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeChip(
                label: 'WORK',
                active: !_isBreak,
                color: const Color(0xFFFF6B35),
                onTap: () {
                  if (_isRunning) return;
                  setState(() {
                    _isBreak = false;
                    _secondsLeft = _workMinutes * 60;
                  });
                },
              ),
              const SizedBox(width: 12),
              _ModeChip(
                label: 'BREAK',
                active: _isBreak,
                color: const Color(0xFF43A047),
                onTap: () {
                  if (_isRunning) return;
                  setState(() {
                    _isBreak = true;
                    _secondsLeft = _breakMinutes * 60;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          // circular timer
          _CircularTimer(
            progress: _progress,
            color: _timerColor,
            label: _formattedTime,
            sublabel: _isBreak ? '休憩' : '集中',
            isRunning: _isRunning,
          ),
          const SizedBox(height: 32),
          // pomodoro count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF6B35),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '$_pomodoroCountポモドーロ (本日)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // task label
          TextField(
            controller: _taskController,
            enabled: !_isRunning,
            decoration: InputDecoration(
              hintText: '今集中すること (例: ER図設計)',
              prefixIcon: const Icon(Icons.edit_note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          // preset buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _presets.map((p) {
              final (label, work, brk) = p;
              final selected = work == _workMinutes && brk == _breakMinutes;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: _isRunning
                      ? null
                      : (v) {
                          if (!v) return;
                          setState(() {
                            _workMinutes = work;
                            _breakMinutes = brk;
                            _secondsLeft = (_isBreak ? brk : work) * 60;
                          });
                        },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning) ...[
                ElevatedButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('開始'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _timerColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _pause,
                  icon: const Icon(Icons.pause),
                  label: const Text('一時停止'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('中止'),
                ),
              ],
              if (!_isRunning && _secondsLeft < _workMinutes * 60 - 1) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _resume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('再開'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_isRunning)
            TextButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop, color: Color(0xFFE53935)),
              label: const Text(
                'セッションを中止',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator());
    }
    final totalSessions = (_stats['total_sessions'] as num?)?.toInt() ?? 0;
    final completedSessions =
        (_stats['completed_sessions'] as num?)?.toInt() ?? 0;
    final totalMinutes = (_stats['total_minutes'] as num?)?.toInt() ?? 0;
    final streakDays = (_stats['streak_days'] as num?)?.toInt() ?? 0;
    final focusScore = (_stats['focus_score'] as num?)?.toInt() ?? 0;
    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _StatCard(
                icon: Icons.check_circle,
                color: const Color(0xFF4CAF50),
                label: '完了セッション',
                value: '$completedSessions',
                sub: '/ $totalSessions セッション',
              ),
              _StatCard(
                icon: Icons.access_time_filled,
                color: const Color(0xFFFF6B35),
                label: '累計集中時間',
                value: '$totalMinutes分',
                sub: '(30日)',
              ),
              _StatCard(
                icon: Icons.local_fire_department,
                color: const Color(0xFFFFA000),
                label: '連続集中日',
                value: '$streakDays日',
                sub: 'ストリーク',
              ),
              _StatCard(
                icon: Icons.bolt,
                color: const Color(0xFF3D5AFE),
                label: '集中スコア',
                value: '$focusScore',
                sub: '/ 100',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // focus score bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '集中スコア (30日)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: focusScore / 100.0,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                    color: _scoreColor(focusScore),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _scoreLabel(focusScore),
                    style: TextStyle(
                      fontSize: 12,
                      color: _scoreColor(focusScore),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // session history
          Text(
            'セッション履歴 (直近30日)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('セッション履歴はありません'),
              ),
            )
          else
            ..._sessions.take(20).map((s) {
              final label = s['task_label']?.toString() ?? '集中作業';
              final mins = s['duration_minutes']?.toString() ?? '25';
              final status = s['status']?.toString() ?? '';
              final startedAt = s['started_at'] != null
                  ? DateTime.tryParse(s['started_at'].toString())
                  : null;
              final dateStr = startedAt != null
                  ? '${startedAt.month}/${startedAt.day} '
                      '${startedAt.hour.toString().padLeft(2, '0')}:'
                      '${startedAt.minute.toString().padLeft(2, '0')}'
                  : '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'active'
                            ? Icons.play_circle
                            : Icons.cancel,
                    color: status == 'completed'
                        ? const Color(0xFF4CAF50)
                        : status == 'active'
                            ? const Color(0xFF3D5AFE)
                            : const Color(0xFF9CA3AF),
                  ),
                  title: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(dateStr),
                  trailing: Text(
                    '$mins分',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 70) return const Color(0xFF4CAF50);
    if (score >= 40) return const Color(0xFFFFA000);
    return const Color(0xFFE53935);
  }

  String _scoreLabel(int score) {
    if (score >= 70) return '集中できています！この調子を維持しましょう';
    if (score >= 40) return 'まずまずです。もう少し集中セッションを増やしましょう';
    return '集中セッションを積み上げてスコアを上げましょう';
  }
}

// ---- sub-widgets ----

class _CircularTimer extends StatelessWidget {
  const _CircularTimer({
    required this.progress,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.isRunning,
  });

  final double progress;
  final Color color;
  final String label;
  final String sublabel;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _TimerPainter(
          progress: progress,
          color: color,
          bgColor: color.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  sublabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              if (isRunning) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '集中中',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPainter extends CustomPainter {
  _TimerPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  final double progress;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerPainter old) =>
      old.progress != progress || old.color != color;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
