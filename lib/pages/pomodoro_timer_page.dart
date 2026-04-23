import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ポモドーロタイマーページ
/// pomodoro-timer Edge Function と連携して作業セッションを記録・分析
class PomodoroTimerPage extends StatefulWidget {
  const PomodoroTimerPage({super.key});

  @override
  State<PomodoroTimerPage> createState() => _PomodoroTimerPageState();
}

class _PomodoroTimerPageState extends State<PomodoroTimerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _sessions = [];

  static const _workMinutes = 25;
  static const _breakMinutes = 5;

  Timer? _timer;
  int _secondsLeft = _workMinutes * 60;
  bool _isWorking = true;
  bool _isRunning = false;
  int _completedPomodoros = 0;
  final _taskCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('tools-hub', body: {'action': 'pomodoro.history'});
      final data = response.data;
      if (data is Map<String, dynamic> && data['sessions'] is List) {
        setState(
          () => _sessions =
              (data['sessions'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _sessions = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'セッション一覧の取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startStop() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          _onTimerComplete();
        }
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isWorking = true;
      _secondsLeft = _workMinutes * 60;
    });
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    setState(() => _isRunning = false);
    if (_isWorking) {
      setState(() {
        _completedPomodoros++;
        _isWorking = false;
        _secondsLeft = _breakMinutes * 60;
      });
      await _saveSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ポモドーロ完了！5分休憩しましょう'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        _isWorking = true;
        _secondsLeft = _workMinutes * 60;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('休憩終了！次のポモドーロを始めましょう')),
        );
      }
    }
  }

  Future<void> _saveSession() async {
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'pomodoro.complete',
          'duration_min': _workMinutes,
        },
      );
      await _fetchSessions();
    } catch (_) {}
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timerColor =
        _isWorking ? const Color(0xFFFF6B35) : const Color(0xFF4CAF50);
    final progress = _isWorking
        ? (_workMinutes * 60 - _secondsLeft) / (_workMinutes * 60)
        : (_breakMinutes * 60 - _secondsLeft) / (_breakMinutes * 60);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポモドーロタイマー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSessions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // タイマー
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Chip(
                    label: Text(
                      _isWorking ? '作業中 🍅' : '休憩中 ☕',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    backgroundColor: timerColor.withAlpha(30),
                    labelStyle: TextStyle(
                      color: timerColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: isDark
                                ? const Color(0xFF424242)
                                : const Color(0xFFEEEEEE),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(timerColor),
                          ),
                        ),
                        Text(
                          _formatTime(_secondsLeft),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: timerColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _taskCtrl,
                      decoration: const InputDecoration(
                        labelText: '今やること（任意）',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          size: 20,
                        ),
                        label: Text(_isRunning ? '一時停止' : '開始'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: timerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _startStop,
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('リセット'),
                        onPressed: _reset,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '今日の完了数: $_completedPomodoros ポモドーロ',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // セッション履歴
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'セッション履歴',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            if (_sessions.isEmpty && !_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'セッション履歴はありません',
                  style: TextStyle(
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _sessions.length > 10 ? 10 : _sessions.length,
                itemBuilder: (context, i) {
                  final s = _sessions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.emoji_events,
                      color: Colors.orange,
                      size: 18,
                    ),
                    title: Text(
                      s['task_name'] as String? ?? '作業セッション',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    subtitle: Text(
                      '${s['duration_minutes'] ?? 25}分  ${(s['completed_at'] as String? ?? '').substring(0, 10)}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
